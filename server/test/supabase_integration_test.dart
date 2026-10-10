import 'dart:convert';
import 'dart:io';

import 'package:cardgames_server/cardgames_server.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Runs against a local Supabase stack (`npx supabase start`), with real
/// tokens from Supabase Auth, the real Postgres store and the migrations'
/// row-level security. `tool/backend_check.sh` sets the variables below
/// from `supabase status`; without them the tests are skipped.
final Map<String, String> env = Platform.environment;
final String? databaseUrl = env['CARDGAMES_TEST_DATABASE_URL'];
final String? apiUrl = env['CARDGAMES_TEST_SUPABASE_URL'];
final String? publishableKey = env['CARDGAMES_TEST_SUPABASE_KEY'];
final String? serviceKey = env['CARDGAMES_TEST_SUPABASE_SERVICE_KEY'];

void main() {
  final skip = [databaseUrl, apiUrl, publishableKey, serviceKey].contains(null)
      ? 'needs a local Supabase stack; run tool/backend_check.sh'
      : null;
  late PostgresStore store;
  late Handler handler;
  late Connection db;
  final client = http.Client();
  final wonLog = playMatch(seed: seedWhere(won: true), stake: 500);
  final wonCoins = coinsOf(wonLog);

  setUpAll(() async {
    if (skip != null) return;
    store = PostgresStore.fromUrl('${databaseUrl!}?sslmode=disable');
    db = await Connection.open(
      Endpoint(
        host: Uri.parse(databaseUrl!).host,
        port: Uri.parse(databaseUrl!).port,
        database: 'postgres',
        username: 'postgres',
        password: 'postgres',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    handler = buildHandler(
      service: SyncService(store: store),
      verifier: SupabaseTokenVerifier(
        supabaseUrl: Uri.parse(apiUrl!),
        apiKey: publishableKey!,
      ),
    );
  });

  tearDownAll(() async {
    if (skip != null) return;
    await store.close();
    await db.close();
    client.close();
  });

  Map<String, String> headers(String key, [String? token]) => {
    'apikey': key,
    'Authorization': 'Bearer ${token ?? key}',
    'Content-Type': 'application/json',
  };

  /// A new anonymous user: its ID and access token.
  Future<(String, String)> guest() async {
    final response = await client.post(
      Uri.parse('$apiUrl/auth/v1/signup'),
      headers: headers(publishableKey!),
      body: '{}',
    );
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final user = body['user']! as Map<String, Object?>;
    return (user['id']! as String, body['access_token']! as String);
  }

  /// A new user signed in with a password, standing in for a Google user.
  Future<(String, String)> signedIn() async {
    final email = 'player-${uuidV7()}@example.test';
    const password = 'local-test-password-1';
    final created = await client.post(
      Uri.parse('$apiUrl/auth/v1/admin/users'),
      headers: headers(serviceKey!),
      body: jsonEncode({
        'email': email,
        'password': password,
        'email_confirm': true,
      }),
    );
    expect(created.statusCode, 200, reason: created.body);
    final response = await client.post(
      Uri.parse('$apiUrl/auth/v1/token?grant_type=password'),
      headers: headers(publishableKey!),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final user = body['user']! as Map<String, Object?>;
    return (user['id']! as String, body['access_token']! as String);
  }

  Future<(int, Map<String, Object?>)> call(
    String method,
    String path,
    String token, [
    Object? body,
  ]) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'Authorization': 'Bearer $token'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, Object?>,
    );
  }

  /// Uploads [log] as a fresh match in batches of 50; returns the last ack.
  /// Unless [ownGame] is false the match gets a game of its own, so that the
  /// same log can go up again (AGENTS.md §6.13); the profile is new unless
  /// [profileId] is given.
  Future<SyncAck> upload(
    String token,
    List<Raw> log, {
    bool ownGame = true,
    String? profileId,
  }) async {
    final created = log.first;
    final events = chain(
      [
        if (ownGame)
          raw(created.type, created.actor, {
            ...created.payload,
            'series': SeriesRef.first(uuidV7()).toJson(),
          })
        else
          created,
        ...log.skip(1),
      ],
      matchId: uuidV7(),
      profileId: profileId ?? uuidV7(),
      deviceId: uuidV7(),
    );
    late SyncAck ack;
    for (var i = 0; i < events.length; i += 50) {
      final (status, body) = await call(
        'POST',
        ServerApi.sync,
        token,
        UploadBatch(
          matchId: events.first.matchId,
          events: events.sublist(i, (i + 50).clamp(0, events.length)),
        ).toJson(),
      );
      expect(status, 200, reason: '$body');
      ack = SyncAck.fromJson(body);
    }
    return ack;
  }

  Future<List<Map<String, Object?>>> ledgerOf(String userId) async {
    final rows = await db.execute(
      Sql.named(
        'select reason, delta from public.wallet_ledger '
        'where user_id = @u:uuid order by id',
      ),
      parameters: {'u': userId},
    );
    return [for (final row in rows) row.toColumnMap()];
  }

  test(
    'a match uploaded with a real token is credited once in Postgres',
    () async {
      final (id, token) = await guest();
      final ack = await upload(token, wonLog);
      expect(ack.status, MatchSyncStatus.accepted);
      expect(ack.wallet.balance, 1000 + wonCoins);
      final ledger = await ledgerOf(id);
      expect(ledger.first, {'reason': 'welcomeGift', 'delta': 1000});
      expect(ledger.map((e) => e['reason']), contains('matchWon'));
      final (_, wallet) = await call('GET', ServerApi.wallet, token);
      expect(WalletState.fromJson(wallet).balance, 1000 + wonCoins);
    },
    skip: skip,
  );

  test('players read only their own rows, and nobody writes', () async {
    final (aId, aToken) = await guest();
    await upload(aToken, wonLog);
    final (bId, bToken) = await guest();
    await call('GET', ServerApi.wallet, bToken);

    Future<http.Response> rest(String table, String token) => client.get(
      Uri.parse('$apiUrl/rest/v1/$table?select=*'),
      headers: headers(publishableKey!, token),
    );

    final mine = jsonDecode((await rest('wallet_ledger', aToken)).body) as List;
    expect(mine, isNotEmpty);
    expect(mine.every((row) => (row as Map)['user_id'] == aId), isTrue);
    final theirs =
        jsonDecode((await rest('wallet_ledger', bToken)).body) as List;
    expect(theirs.map((row) => (row as Map)['user_id']).toSet(), {bId});
    final matches = jsonDecode((await rest('matches', aToken)).body) as List;
    expect(matches.single, containsPair('status', 'accepted'));

    // The API's anonymous role reads nothing; no player reads the bonus
    // record; no player writes the ledger.
    expect((await rest('wallet_ledger', publishableKey!)).statusCode, 401);
    expect(
      (await rest('signup_bonus_claims', aToken)).statusCode,
      anyOf(401, 403),
    );
    final forged = await client.post(
      Uri.parse('$apiUrl/rest/v1/wallet_ledger'),
      headers: headers(publishableKey!, aToken),
      body: jsonEncode({
        'user_id': aId,
        'delta': 1000000,
        'reason': 'forged',
        'ref_id': 'x',
      }),
    );
    expect(forged.statusCode, anyOf(401, 403), reason: forged.body);
    expect(
      (await ledgerOf(aId)).where((e) => e['reason'] == 'forged'),
      isEmpty,
    );
  }, skip: skip);

  test(
    "a game's matches are checked against Postgres's records (§6.13)",
    () async {
      final (_, token) = await guest();
      final profile = uuidV7();
      final game = uuidV7();
      final wonSeed = seedWhere(won: true);
      final first = await upload(
        token,
        playMatch(
          seed: wonSeed,
          series: SeriesRef.first(game),
          continueGame: true,
        ),
        ownGame: false,
        profileId: profile,
      );
      expect(first.status, MatchSyncStatus.accepted);
      final second = playMatch(
        seed: wonSeed,
        series: SeriesRef(id: game, match: 2, record: 1),
      );
      final ack = await upload(
        token,
        second,
        ownGame: false,
        profileId: profile,
      );
      expect(ack.status, MatchSyncStatus.accepted);
      final rows = await db.execute(
        Sql.named(
          'select series_match, record_after, series_continues '
          'from public.matches where series_id = @g:uuid '
          'order by series_match',
        ),
        parameters: {'g': game},
      );
      expect(
        [for (final row in rows) row.toList()],
        [
          [1, 1, true],
          [2, 2, false],
        ],
      );
      final branch = await upload(
        token,
        second,
        ownGame: false,
        profileId: profile,
      );
      expect(branch.status, MatchSyncStatus.rejected);
      expect(branch.reason, 'another match holds its place in the game');
    },
    skip: skip,
  );

  test('a guest merges into a signed-in account', () async {
    final (guestId, guestToken) = await guest();
    await upload(guestToken, wonLog);
    final (userId, userToken) = await signedIn();
    final (status, body) = await call(
      'POST',
      ServerApi.merge,
      userToken,
      MergeRequest(guestAccessToken: guestToken).toJson(),
    );
    expect(status, 200, reason: '$body');
    final merged = MergeResult.fromJson(body);
    expect(merged.coinsMoved, wonCoins);
    expect(merged.wallet.balance, 1000 + wonCoins);
    expect(
      (await ledgerOf(guestId))
          .fold<int>(0, (s, e) => s + (e['delta']! as int)),
      0,
    );
    expect((await call('GET', ServerApi.wallet, guestToken)).$1, 403);
    expect((await ledgerOf(userId)).last, {
      'reason': 'mergedIn',
      'delta': wonCoins,
    });
  }, skip: skip);

  test('a made-up token is refused by Supabase Auth', () async {
    expect((await call('GET', ServerApi.wallet, 'made-up')).$1, 401);
  }, skip: skip);
}
