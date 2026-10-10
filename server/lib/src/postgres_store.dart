import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:postgres/postgres.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'store.dart';

/// The store in Postgres: the Supabase database, with the tables of
/// `supabase/migrations` (docs/decisions.md D-029).
///
/// The server connects as the tables' owner, so row-level security, which
/// guards the same tables from players, does not apply to it.
final class PostgresStore implements ServerStore {
  /// A store on [_pool].
  PostgresStore(this._pool);

  /// A store connecting with [url], a `postgresql://` connection string.
  factory PostgresStore.fromUrl(String url) =>
      PostgresStore(Pool<void>.withUrl(url));

  final Pool<void> _pool;

  /// Closes the connections.
  Future<void> close() => _pool.close();

  @override
  Future<T> transaction<T>(
    List<String> userIds,
    Future<T> Function(StoreTransaction tx) body,
  ) => _pool.runTx((session) async {
    // One account's requests run one at a time; locks are taken in a fixed
    // order so that two merges cannot wait on each other.
    for (final id in {...userIds}.toList()..sort()) {
      await session.execute(
        Sql.named(
          'select pg_advisory_xact_lock(hashtextextended(@id:text, 0))',
        ),
        parameters: {'id': id},
      );
    }
    return body(_PostgresTransaction(session));
  });
}

final class _PostgresTransaction implements StoreTransaction {
  _PostgresTransaction(this._s);

  final TxSession _s;

  Future<Result> _run(String sql, [Map<String, Object?>? parameters]) =>
      _s.execute(Sql.named(sql), parameters: parameters ?? const {});

  @override
  Future<String?> profileOwner(String profileId) async {
    final rows = await _run(
      'select user_id from public.profiles where profile_id = @p:uuid',
      {'p': profileId},
    );
    return rows.isEmpty ? null : rows.first[0]! as String;
  }

  @override
  Future<void> bindProfile({
    required String profileId,
    required String userId,
    required String deviceId,
  }) async {
    await _run(
      'insert into public.profiles (profile_id, user_id, device_id) '
      'values (@p:uuid, @u:uuid, @d:uuid)',
      {'p': profileId, 'u': userId, 'd': deviceId},
    );
  }

  @override
  Future<void> rebindProfiles({
    required String fromUserId,
    required String toUserId,
  }) async {
    await _run(
      'update public.profiles set user_id = @to:uuid where user_id = @from:uuid',
      {'from': fromUserId, 'to': toUserId},
    );
  }

  static const String _matchColumns =
      'match_id::text, user_id::text, profile_id::text, game_id, '
      'rules_version, last_seq, last_hash, status, reject_reason, coins, '
      'series_id::text, series_match, table_key, record_after, '
      'series_continues';

  static StoredMatch _matchOf(ResultRow row) => StoredMatch(
    matchId: row[0]! as String,
    userId: row[1]! as String,
    profileId: row[2]! as String,
    gameId: row[3]! as String,
    rulesVersion: row[4]! as int,
    lastSeq: row[5]! as int,
    lastHash: row[6]! as String,
    status: MatchSyncStatus.values.byName(row[7]! as String),
    reason: row[8] as String?,
    coins: row[9] as int?,
    seriesId: row[10] as String?,
    seriesMatch: row[11] as int?,
    tableKey: row[12] as String?,
    recordAfter: row[13] as int?,
    seriesContinues: row[14] as bool?,
  );

  @override
  Future<StoredMatch?> match(String matchId) async {
    final rows = await _run(
      'select $_matchColumns from public.matches where match_id = @m:uuid',
      {'m': matchId},
    );
    return rows.isEmpty ? null : _matchOf(rows.first);
  }

  @override
  Future<StoredMatch?> seriesMatch(String seriesId, int match) async {
    final rows = await _run(
      'select $_matchColumns from public.matches '
      'where series_id = @s:uuid and series_match = @n:int4',
      {'s': seriesId, 'n': match},
    );
    return rows.isEmpty ? null : _matchOf(rows.first);
  }

  @override
  Future<void> putMatch(StoredMatch match) async {
    await _run(
      'insert into public.matches (match_id, user_id, profile_id, game_id, '
      'rules_version, last_seq, last_hash, status, reject_reason, coins, '
      'series_id, series_match, table_key, record_after, series_continues) '
      'values (@m:uuid, @u:uuid, @p:uuid, @g:text, @v:int4, @seq:int4, '
      '@hash:text, @status:text, @reason:text, @coins:int8, @sid:uuid, '
      '@sn:int4, @key:text, @rec:int4, @cont:boolean) '
      'on conflict (match_id) do update set user_id = excluded.user_id, '
      'last_seq = excluded.last_seq, last_hash = excluded.last_hash, '
      'status = excluded.status, reject_reason = excluded.reject_reason, '
      'coins = excluded.coins, series_id = excluded.series_id, '
      'series_match = excluded.series_match, '
      'table_key = excluded.table_key, '
      'record_after = excluded.record_after, '
      'series_continues = excluded.series_continues, updated_at = now()',
      {
        'm': match.matchId,
        'u': match.userId,
        'p': match.profileId,
        'g': match.gameId,
        'v': match.rulesVersion,
        'seq': match.lastSeq,
        'hash': match.lastHash,
        'status': match.status.name,
        'reason': match.reason,
        'coins': match.coins,
        'sid': match.seriesId,
        'sn': match.seriesMatch,
        'key': match.tableKey,
        'rec': match.recordAfter,
        'cont': match.seriesContinues,
      },
    );
  }

  @override
  Future<void> moveOpenMatches({
    required String fromUserId,
    required String toUserId,
  }) async {
    await _run(
      'update public.matches set user_id = @to:uuid, updated_at = now() '
      "where user_id = @from:uuid and status = 'open'",
      {'from': fromUserId, 'to': toUserId},
    );
  }

  @override
  Future<List<EventEnvelope>> events(String matchId) async {
    final rows = await _run(
      'select envelope from public.match_events where match_id = @m:uuid '
      'order by seq',
      {'m': matchId},
    );
    return [
      for (final row in rows)
        EventEnvelope.fromJson(
          jsonDecode(row[0]! as String) as Map<String, Object?>,
        ),
    ];
  }

  @override
  Future<bool> hasEvent(String eventId) async {
    final rows = await _run(
      'select 1 from public.match_events where event_id = @e:uuid',
      {'e': eventId},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> addEvents(
    String matchId,
    String userId,
    List<EventEnvelope> events,
  ) async {
    for (final event in events) {
      await _run(
        'insert into public.match_events (event_id, match_id, user_id, seq, '
        'envelope) values (@e:uuid, @m:uuid, @u:uuid, @seq:int4, @json:text)',
        {
          'e': event.eventId,
          'm': matchId,
          'u': userId,
          'seq': event.seq,
          'json': canonicalJson(event.toJson()),
        },
      );
    }
  }

  @override
  Future<bool> credit({
    required String userId,
    required int delta,
    required String reason,
    required String refId,
  }) async {
    final rows = await _run(
      'insert into public.wallet_ledger (user_id, delta, reason, ref_id) '
      'values (@u:uuid, @d:int8, @r:text, @ref:text) '
      'on conflict (user_id, reason, ref_id) do nothing returning id',
      {'u': userId, 'd': delta, 'r': reason, 'ref': refId},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<int> balance(String userId) async {
    final rows = await _run(
      'select coalesce(sum(delta), 0)::int8 from public.wallet_ledger '
      'where user_id = @u:uuid',
      {'u': userId},
    );
    return rows.first[0]! as int;
  }

  @override
  Future<int> sumOf(String userId, Set<String> reasons) async {
    final rows = await _run(
      'select coalesce(sum(delta), 0)::int8 from public.wallet_ledger '
      'where user_id = @u:uuid and reason = any(@r:_text)',
      {'u': userId, 'r': reasons.toList()},
    );
    return rows.first[0]! as int;
  }

  @override
  Future<bool> claimSignupBonus(String provider, String subjectHash) async {
    final rows = await _run(
      'insert into public.signup_bonus_claims (provider, subject_hash) '
      'values (@p:text, @h:text) on conflict do nothing returning 1',
      {'p': provider, 'h': subjectHash},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<({String toUserId, int coins})?> mergeOf(String userId) async {
    final rows = await _run(
      'select to_user_id::text, coins from public.account_merges '
      'where from_user_id = @u:uuid',
      {'u': userId},
    );
    if (rows.isEmpty) return null;
    return (toUserId: rows.first[0]! as String, coins: rows.first[1]! as int);
  }

  @override
  Future<void> recordMerge({
    required String fromUserId,
    required String toUserId,
    required int coins,
  }) async {
    await _run(
      'insert into public.account_merges (from_user_id, to_user_id, coins) '
      'values (@from:uuid, @to:uuid, @coins:int8)',
      {'from': fromUserId, 'to': toUserId, 'coins': coins},
    );
  }
}
