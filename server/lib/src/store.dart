import 'package:sync_protocol/sync_protocol.dart';

/// The server's record of an uploaded match.
final class StoredMatch {
  /// Creates a record.
  const StoredMatch({
    required this.matchId,
    required this.userId,
    required this.profileId,
    required this.gameId,
    required this.rulesVersion,
    required this.lastSeq,
    required this.lastHash,
    required this.status,
    this.reason,
    this.coins,
    this.seriesId,
    this.seriesMatch,
    this.tableKey,
    this.recordAfter,
    this.seriesContinues,
  });

  /// The match.
  final String matchId;

  /// The account its coins go to.
  final String userId;

  /// The device profile that logged it (AGENTS.md §10).
  final String profileId;

  /// Its game.
  final String gameId;

  /// The rules version it was played under.
  final int rulesVersion;

  /// The last `seq` held, or -1 before any.
  final int lastSeq;

  /// The hash of the last event held.
  final String lastHash;

  /// Where the server stands on it.
  final MatchSyncStatus status;

  /// Why it was rejected.
  final String? reason;

  /// The coins it moved, once accepted.
  final int? coins;

  /// The game it belongs to (AGENTS.md §6.13), once its log has been read.
  final String? seriesId;

  /// Its number in the game, from 1.
  final int? seriesMatch;

  /// What must stay the same in every match of the game (`tableKeyOf`).
  final String? tableKey;

  /// The player's team's match record in the game after it, once accepted:
  /// the server's own count, from the replayed logs.
  final int? recordAfter;

  /// Whether the game goes on after it, once accepted.
  final bool? seriesContinues;

  /// A copy with the given fields changed.
  StoredMatch copyWith({
    String? userId,
    int? lastSeq,
    String? lastHash,
    MatchSyncStatus? status,
    String? reason,
    int? coins,
    String? seriesId,
    int? seriesMatch,
    String? tableKey,
    int? recordAfter,
    bool? seriesContinues,
  }) => StoredMatch(
    matchId: matchId,
    userId: userId ?? this.userId,
    profileId: profileId,
    gameId: gameId,
    rulesVersion: rulesVersion,
    lastSeq: lastSeq ?? this.lastSeq,
    lastHash: lastHash ?? this.lastHash,
    status: status ?? this.status,
    reason: reason ?? this.reason,
    coins: coins ?? this.coins,
    seriesId: seriesId ?? this.seriesId,
    seriesMatch: seriesMatch ?? this.seriesMatch,
    tableKey: tableKey ?? this.tableKey,
    recordAfter: recordAfter ?? this.recordAfter,
    seriesContinues: seriesContinues ?? this.seriesContinues,
  );
}

/// Where the server keeps profiles, match logs and the coin ledger.
abstract interface class ServerStore {
  /// Runs [body] as one transaction: all of its writes happen, or none.
  /// Two transactions that name the same account in [userIds] never run at
  /// the same time.
  Future<T> transaction<T>(
    List<String> userIds,
    Future<T> Function(StoreTransaction tx) body,
  );
}

/// The reads and writes of one transaction.
abstract interface class StoreTransaction {
  /// The account a device profile is bound to, if any.
  Future<String?> profileOwner(String profileId);

  /// Binds [profileId] to [userId].
  Future<void> bindProfile({
    required String profileId,
    required String userId,
    required String deviceId,
  });

  /// Binds every profile of [fromUserId] to [toUserId].
  Future<void> rebindProfiles({
    required String fromUserId,
    required String toUserId,
  });

  /// The record of [matchId], if any.
  Future<StoredMatch?> match(String matchId);

  /// Creates or replaces the record of a match. One match at most holds
  /// each place in a game.
  Future<void> putMatch(StoredMatch match);

  /// The match that holds place [match] in game [seriesId], if any.
  Future<StoredMatch?> seriesMatch(String seriesId, int match);

  /// Gives [toUserId] the matches of [fromUserId] that are still open.
  Future<void> moveOpenMatches({
    required String fromUserId,
    required String toUserId,
  });

  /// The events held for [matchId], by `seq`.
  Future<List<EventEnvelope>> events(String matchId);

  /// Whether an event with this ID is already held, for any match.
  Future<bool> hasEvent(String eventId);

  /// Adds [events] to [matchId], uploaded by [userId].
  Future<void> addEvents(
    String matchId,
    String userId,
    List<EventEnvelope> events,
  );

  /// Adds a ledger entry, unless one with the same user, reason and
  /// reference exists (AGENTS.md §11). Returns whether it was added.
  Future<bool> credit({
    required String userId,
    required int delta,
    required String reason,
    required String refId,
  });

  /// The sum of [userId]'s ledger.
  Future<int> balance(String userId);

  /// The sum of [userId]'s ledger entries with one of [reasons].
  Future<int> sumOf(String userId, Set<String> reasons);

  /// Records that the Google account with [subjectHash] has had the
  /// sign-up bonus. Returns false if it already had (docs/decisions.md
  /// D-032).
  Future<bool> claimSignupBonus(String provider, String subjectHash);

  /// The account [userId] was merged into, and the coins moved, if it was.
  Future<({String toUserId, int coins})?> mergeOf(String userId);

  /// Records that [fromUserId] was merged into [toUserId], moving [coins].
  Future<void> recordMerge({
    required String fromUserId,
    required String toUserId,
    required int coins,
  });
}

/// A store in memory, for tests. Transactions run one at a time and are
/// rolled back if they throw.
final class MemoryStore implements ServerStore {
  _MemoryState _state = _MemoryState();
  Future<void> _queue = Future.value();

  /// The ledger, for tests: user, delta, reason and reference.
  List<({String userId, int delta, String reason, String refId})> get ledger =>
      List.unmodifiable(_state.ledger);

  /// The record of [matchId], for tests.
  StoredMatch? matchOf(String matchId) => _state.matches[matchId];

  /// The events held for [matchId], for tests.
  List<EventEnvelope> eventsOf(String matchId) => [
    for (final event in _state.events.values)
      if (event.matchId == matchId) event,
  ]..sort((a, b) => a.seq.compareTo(b.seq));

  @override
  Future<T> transaction<T>(
    List<String> userIds,
    Future<T> Function(StoreTransaction tx) body,
  ) {
    final result = _queue.then((_) async {
      final working = _state.copy();
      final value = await body(_MemoryTransaction(working));
      _state = working;
      return value;
    });
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

final class _MemoryState {
  final Map<String, (String userId, String deviceId)> profiles = {};
  final Map<String, StoredMatch> matches = {};
  final Map<String, EventEnvelope> events = {};
  final List<({String userId, int delta, String reason, String refId})> ledger =
      [];
  final Set<String> claims = {};
  final Map<String, ({String toUserId, int coins})> merges = {};

  _MemoryState copy() => _MemoryState()
    ..profiles.addAll(profiles)
    ..matches.addAll(matches)
    ..events.addAll(events)
    ..ledger.addAll(ledger)
    ..claims.addAll(claims)
    ..merges.addAll(merges);
}

final class _MemoryTransaction implements StoreTransaction {
  _MemoryTransaction(this._s);

  final _MemoryState _s;

  @override
  Future<String?> profileOwner(String profileId) async =>
      _s.profiles[profileId]?.$1;

  @override
  Future<void> bindProfile({
    required String profileId,
    required String userId,
    required String deviceId,
  }) async => _s.profiles[profileId] = (userId, deviceId);

  @override
  Future<void> rebindProfiles({
    required String fromUserId,
    required String toUserId,
  }) async {
    for (final MapEntry(key: id, value: (owner, device))
        in _s.profiles.entries.toList()) {
      if (owner == fromUserId) _s.profiles[id] = (toUserId, device);
    }
  }

  @override
  Future<StoredMatch?> match(String matchId) async => _s.matches[matchId];

  @override
  Future<void> putMatch(StoredMatch match) async {
    // As in Postgres: one match per place in a game.
    final holder = match.seriesId == null
        ? null
        : await seriesMatch(match.seriesId!, match.seriesMatch!);
    if (holder != null && holder.matchId != match.matchId) {
      throw StateError('Place ${match.seriesMatch} of a game is taken');
    }
    _s.matches[match.matchId] = match;
  }

  @override
  Future<StoredMatch?> seriesMatch(String seriesId, int match) async {
    for (final stored in _s.matches.values) {
      if (stored.seriesId == seriesId && stored.seriesMatch == match) {
        return stored;
      }
    }
    return null;
  }

  @override
  Future<void> moveOpenMatches({
    required String fromUserId,
    required String toUserId,
  }) async {
    for (final match in _s.matches.values.toList()) {
      if (match.userId == fromUserId && match.status == MatchSyncStatus.open) {
        _s.matches[match.matchId] = match.copyWith(userId: toUserId);
      }
    }
  }

  @override
  Future<List<EventEnvelope>> events(String matchId) async => [
    for (final event in _s.events.values)
      if (event.matchId == matchId) event,
  ]..sort((a, b) => a.seq.compareTo(b.seq));

  @override
  Future<bool> hasEvent(String eventId) async => _s.events.containsKey(eventId);

  @override
  Future<void> addEvents(
    String matchId,
    String userId,
    List<EventEnvelope> events,
  ) async {
    // As in Postgres: events refer to their match's record.
    if (!_s.matches.containsKey(matchId)) {
      throw StateError('No record of match $matchId');
    }
    for (final event in events) {
      _s.events[event.eventId] = event;
    }
  }

  @override
  Future<bool> credit({
    required String userId,
    required int delta,
    required String reason,
    required String refId,
  }) async {
    final exists = _s.ledger.any(
      (e) => e.userId == userId && e.reason == reason && e.refId == refId,
    );
    if (exists) return false;
    _s.ledger.add((userId: userId, delta: delta, reason: reason, refId: refId));
    return true;
  }

  @override
  Future<int> balance(String userId) async => _s.ledger
      .where((e) => e.userId == userId)
      .fold<int>(0, (sum, e) => sum + e.delta);

  @override
  Future<int> sumOf(String userId, Set<String> reasons) async => _s.ledger
      .where((e) => e.userId == userId && reasons.contains(e.reason))
      .fold<int>(0, (sum, e) => sum + e.delta);

  @override
  Future<bool> claimSignupBonus(String provider, String subjectHash) async =>
      _s.claims.add('$provider:$subjectHash');

  @override
  Future<({String toUserId, int coins})?> mergeOf(String userId) async =>
      _s.merges[userId];

  @override
  Future<void> recordMerge({
    required String fromUserId,
    required String toUserId,
    required int coins,
  }) async => _s.merges[fromUserId] = (toUserId: toUserId, coins: coins);
}
