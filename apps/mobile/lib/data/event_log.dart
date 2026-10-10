import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:game_core/game_core.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'identity.dart';
import 'local_database.dart';

/// An event to record, before it has its place in a match's chain.
final class NewEvent {
  /// Creates an event of [type] caused by [actor].
  const NewEvent(this.type, this.actor, [this.payload = const {}]);

  /// The event type, for example `twentynine.cardPlayed`.
  final String type;

  /// Who caused it: `seat:N`, `system` or `user`.
  final String actor;

  /// The event's data, as JSON without doubles.
  final Map<String, Object?> payload;
}

/// One of the user's matches with coins at stake, as the wallet reads it.
final class CoinMatch {
  /// Creates the record of a match.
  const CoinMatch({
    required this.matchId,
    required this.gameId,
    required this.status,
    required this.startedAt,
    required this.events,
  });

  /// The match.
  final String matchId;

  /// Its game.
  final String gameId;

  /// Whether it is being played, finished or abandoned.
  final MatchStatus status;

  /// When it was created.
  final DateTime startedAt;

  /// Its economy events, such as the fee paid and rewards pending, in order.
  final List<EventEnvelope> events;
}

/// Where one of the user's matches stands on its way to the server.
final class UploadState {
  /// Creates a state.
  const UploadState({
    required this.matchId,
    required this.gameId,
    required this.status,
    required this.lastSeq,
    required this.ackedSeq,
  });

  /// The match.
  final String matchId;

  /// Its game.
  final String gameId;

  /// Whether it is being played, finished or abandoned.
  final MatchStatus status;

  /// Its last event's `seq`.
  final int lastSeq;

  /// The last `seq` the server has acknowledged, or -1.
  final int ackedSeq;
}

/// What is kept of a match once the server has settled it and its events
/// are deleted (AGENTS.md §9).
final class MatchSummary {
  /// Creates a summary.
  const MatchSummary({
    required this.matchId,
    required this.gameId,
    required this.stake,
    required this.result,
    required this.coins,
    required this.settledAt,
  });

  /// The match.
  final String matchId;

  /// Its game.
  final String gameId;

  /// Its table fee, or 0 for practice.
  final int stake;

  /// How it ended for the player.
  final SettledResult result;

  /// The coins it moved, as the server credited them.
  final int coins;

  /// When the server settled it.
  final DateTime settledAt;
}

/// The economy event types (AGENTS.md §9: entry fee, reward pending).
const List<String> _economyTypes = EventTypes.economy;

/// The device's append-only event log (AGENTS.md §9). Everything a match
/// does is recorded here, in order, before anything else happens to it.
abstract interface class EventLog {
  /// Whose events the log records, and on which device.
  LocalIdentity get identity;

  /// Records [events] at the end of [matchId]'s chain, in order, and returns
  /// them as stored. The first call for a match starts its chain.
  ///
  /// Throws a [StateError] if the match belongs to another user.
  Future<List<EventEnvelope>> append(
    String matchId,
    List<NewEvent> events, {
    required String gameId,
    required int rulesVersion,
  });

  /// Marks [matchId] as finished or abandoned.
  Future<void> setStatus(String matchId, MatchStatus status);

  /// Every event of [matchId], in order.
  Future<List<EventEnvelope>> events(String matchId);

  /// The user's newest match of [gameId] that is still active, if any.
  Future<String?> unfinishedMatch(String gameId);

  /// The user's matches that have economy events, oldest first.
  Future<List<CoinMatch>> coinMatches();

  /// The user's matches the server has not settled yet, oldest first.
  Future<List<UploadState>> uploadStates();

  /// Up to [limit] events of [matchId] from `seq` [fromSeq], in order.
  Future<List<EventEnvelope>> eventsFrom(
    String matchId,
    int fromSeq, {
    int limit = ServerApi.maxBatchEvents,
  });

  /// Records that the server holds [matchId]'s events up to [seq].
  Future<void> markAcked(String matchId, int seq);

  /// Deletes a match the server has settled, keeping only [summary]
  /// (AGENTS.md §9).
  Future<void> settle(MatchSummary summary);

  /// The user's settled matches, newest first.
  Future<List<MatchSummary>> summaries({int limit = 20});
}

EventEnvelope _envelope({
  required LocalIdentity identity,
  required String appVersion,
  required String matchId,
  required String gameId,
  required int rulesVersion,
  required int seq,
  required String prevHash,
  required DateTime now,
  required NewEvent event,
}) => EventEnvelope.next(
  eventId: uuidV7(now: now),
  matchId: matchId,
  seq: seq,
  type: event.type,
  actor: event.actor,
  payload: event.payload,
  clientTime: now,
  userId: identity.userId,
  deviceId: identity.deviceId,
  gameId: gameId,
  rulesVersion: rulesVersion,
  appVersion: appVersion,
  prevHash: prevHash,
);

/// The event log in the encrypted local database.
final class DriftEventLog implements EventLog {
  /// A log in the given database for [identity], stamped with [appVersion].
  DriftEventLog(
    this._db,
    this.identity, {
    required this.appVersion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalDatabase _db;
  final DateTime Function() _clock;

  @override
  final LocalIdentity identity;

  /// The app version written into every event.
  final String appVersion;

  @override
  Future<List<EventEnvelope>> append(
    String matchId,
    List<NewEvent> events, {
    required String gameId,
    required int rulesVersion,
  }) => _db.transaction(() async {
    final now = _clock();
    final millis = now.millisecondsSinceEpoch;
    var match = await (_db.select(
      _db.matches,
    )..where((m) => m.matchId.equals(matchId))).getSingleOrNull();
    if (match == null) {
      match = MatchRow(
        matchId: matchId,
        userId: identity.userId,
        gameId: gameId,
        rulesVersion: rulesVersion,
        status: MatchStatus.active,
        lastSeq: -1,
        lastHash: genesisHash,
        ackedSeq: -1,
        createdAt: millis,
        updatedAt: millis,
      );
      await _db.into(_db.matches).insert(match);
    } else if (match.userId != identity.userId) {
      throw StateError('That match belongs to another user');
    }
    var seq = match.lastSeq;
    var prevHash = match.lastHash;
    final stored = <EventEnvelope>[];
    for (final event in events) {
      seq++;
      final envelope = _envelope(
        identity: identity,
        appVersion: appVersion,
        matchId: matchId,
        gameId: match.gameId,
        rulesVersion: match.rulesVersion,
        seq: seq,
        prevHash: prevHash,
        now: now,
        event: event,
      );
      await _db
          .into(_db.logEvents)
          .insert(
            LogEventsCompanion.insert(
              eventId: envelope.eventId,
              userId: identity.userId,
              matchId: matchId,
              seq: seq,
              type: envelope.type,
              envelope: canonicalJson(envelope.toJson()),
              hash: envelope.hash,
              syncState: SyncState.pending,
            ),
          );
      prevHash = envelope.hash;
      stored.add(envelope);
    }
    await (_db.update(
      _db.matches,
    )..where((m) => m.matchId.equals(matchId))).write(
      MatchesCompanion(
        lastSeq: Value(seq),
        lastHash: Value(prevHash),
        updatedAt: Value(millis),
      ),
    );
    return stored;
  });

  @override
  Future<void> setStatus(String matchId, MatchStatus status) async {
    await (_db.update(_db.matches)..where(
          (m) => m.matchId.equals(matchId) & m.userId.equals(identity.userId),
        ))
        .write(
          MatchesCompanion(
            status: Value(status),
            updatedAt: Value(_clock().millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<List<EventEnvelope>> events(String matchId) async {
    final rows =
        await (_db.select(_db.logEvents)
              ..where(
                (e) =>
                    e.matchId.equals(matchId) &
                    e.userId.equals(identity.userId),
              )
              ..orderBy([(e) => OrderingTerm(expression: e.seq)]))
            .get();
    return [for (final row in rows) _decode(row)];
  }

  @override
  Future<String?> unfinishedMatch(String gameId) async {
    final row =
        await (_db.select(_db.matches)
              ..where(
                (m) =>
                    m.userId.equals(identity.userId) &
                    m.gameId.equals(gameId) &
                    m.status.equalsValue(MatchStatus.active),
              )
              ..orderBy([
                (m) => OrderingTerm(
                  expression: m.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.matchId;
  }

  @override
  Future<List<CoinMatch>> coinMatches() async {
    final query =
        _db.select(_db.logEvents).join([
            innerJoin(
              _db.matches,
              _db.matches.matchId.equalsExp(_db.logEvents.matchId),
            ),
          ])
          ..where(
            _db.logEvents.userId.equals(identity.userId) &
                _db.logEvents.type.isIn(_economyTypes),
          )
          ..orderBy([
            OrderingTerm.asc(_db.matches.createdAt),
            OrderingTerm.asc(_db.logEvents.matchId),
            OrderingTerm.asc(_db.logEvents.seq),
          ]);
    final byMatch = <String, (MatchRow, List<EventEnvelope>)>{};
    for (final row in await query.get()) {
      final match = row.readTable(_db.matches);
      byMatch
          .putIfAbsent(match.matchId, () => (match, []))
          .$2
          .add(_decode(row.readTable(_db.logEvents)));
    }
    return [
      for (final (match, events) in byMatch.values)
        CoinMatch(
          matchId: match.matchId,
          gameId: match.gameId,
          status: match.status,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            match.createdAt,
            isUtc: true,
          ),
          events: events,
        ),
    ];
  }

  @override
  Future<List<UploadState>> uploadStates() async {
    final rows =
        await (_db.select(_db.matches)
              ..where((m) => m.userId.equals(identity.userId))
              ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]))
            .get();
    return [
      for (final row in rows)
        UploadState(
          matchId: row.matchId,
          gameId: row.gameId,
          status: row.status,
          lastSeq: row.lastSeq,
          ackedSeq: row.ackedSeq,
        ),
    ];
  }

  @override
  Future<List<EventEnvelope>> eventsFrom(
    String matchId,
    int fromSeq, {
    int limit = ServerApi.maxBatchEvents,
  }) async {
    final rows =
        await (_db.select(_db.logEvents)
              ..where(
                (e) =>
                    e.matchId.equals(matchId) &
                    e.userId.equals(identity.userId) &
                    e.seq.isBiggerOrEqualValue(fromSeq),
              )
              ..orderBy([(e) => OrderingTerm(expression: e.seq)])
              ..limit(limit))
            .get();
    return [for (final row in rows) _decode(row)];
  }

  @override
  Future<void> markAcked(String matchId, int seq) => _db.transaction(() async {
    await (_db.update(_db.matches)..where(
          (m) =>
              m.matchId.equals(matchId) &
              m.userId.equals(identity.userId) &
              m.ackedSeq.isSmallerThanValue(seq),
        ))
        .write(MatchesCompanion(ackedSeq: Value(seq)));
    await (_db.update(_db.logEvents)..where(
          (e) =>
              e.matchId.equals(matchId) &
              e.userId.equals(identity.userId) &
              e.seq.isSmallerOrEqualValue(seq),
        ))
        .write(const LogEventsCompanion(syncState: Value(SyncState.acked)));
  });

  @override
  Future<void> settle(MatchSummary summary) => _db.transaction(() async {
    await (_db.delete(_db.logEvents)..where(
          (e) =>
              e.matchId.equals(summary.matchId) &
              e.userId.equals(identity.userId),
        ))
        .go();
    await (_db.delete(_db.matches)..where(
          (m) =>
              m.matchId.equals(summary.matchId) &
              m.userId.equals(identity.userId),
        ))
        .go();
    await _db
        .into(_db.matchSummaries)
        .insertOnConflictUpdate(
          MatchSummariesCompanion.insert(
            matchId: summary.matchId,
            userId: identity.userId,
            gameId: summary.gameId,
            stake: summary.stake,
            result: summary.result,
            coins: summary.coins,
            settledAt: summary.settledAt.millisecondsSinceEpoch,
          ),
        );
  });

  @override
  Future<List<MatchSummary>> summaries({int limit = 20}) async {
    final rows =
        await (_db.select(_db.matchSummaries)
              ..where((m) => m.userId.equals(identity.userId))
              ..orderBy([
                (m) => OrderingTerm(
                  expression: m.settledAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        MatchSummary(
          matchId: row.matchId,
          gameId: row.gameId,
          stake: row.stake,
          result: row.result,
          coins: row.coins,
          settledAt: DateTime.fromMillisecondsSinceEpoch(
            row.settledAt,
            isUtc: true,
          ),
        ),
    ];
  }

  static EventEnvelope _decode(LogEventRow row) =>
      EventEnvelope.fromJson(jsonDecode(row.envelope) as Map<String, Object?>);
}

/// An event log kept in memory, for tests and previews.
final class MemoryEventLog implements EventLog {
  /// A log for [identity].
  MemoryEventLog({
    this.identity = const LocalIdentity(deviceId: 'device', userId: 'user'),
    this.appVersion = 'test',
  });

  @override
  final LocalIdentity identity;

  /// The app version written into every event.
  final String appVersion;

  final Map<String, List<EventEnvelope>> _events = {};
  final Map<String, MatchStatus> _status = {};
  final Map<String, String> _games = {};
  final Map<String, int> _acked = {};
  final List<MatchSummary> _summaries = [];

  @override
  Future<List<EventEnvelope>> append(
    String matchId,
    List<NewEvent> events, {
    required String gameId,
    required int rulesVersion,
  }) async {
    final chain = _events.putIfAbsent(matchId, () => []);
    _status.putIfAbsent(matchId, () => MatchStatus.active);
    _games.putIfAbsent(matchId, () => gameId);
    final now = DateTime.now();
    final stored = <EventEnvelope>[];
    for (final event in events) {
      final envelope = _envelope(
        identity: identity,
        appVersion: appVersion,
        matchId: matchId,
        gameId: gameId,
        rulesVersion: rulesVersion,
        seq: chain.length,
        prevHash: chain.isEmpty ? genesisHash : chain.last.hash,
        now: now,
        event: event,
      );
      chain.add(envelope);
      stored.add(envelope);
    }
    return stored;
  }

  @override
  Future<void> setStatus(String matchId, MatchStatus status) async {
    _status[matchId] = status;
  }

  @override
  Future<List<EventEnvelope>> events(String matchId) async =>
      List.of(_events[matchId] ?? const []);

  @override
  Future<String?> unfinishedMatch(String gameId) async {
    String? newest;
    for (final id in _events.keys) {
      if (_games[id] == gameId && _status[id] == MatchStatus.active) {
        newest = id;
      }
    }
    return newest;
  }

  @override
  Future<List<CoinMatch>> coinMatches() async => [
    for (final MapEntry(key: matchId, value: chain) in _events.entries)
      if ([
            for (final event in chain)
              if (_economyTypes.contains(event.type)) event,
          ]
          case final events when events.isNotEmpty)
        CoinMatch(
          matchId: matchId,
          gameId: _games[matchId]!,
          status: _status[matchId]!,
          startedAt: DateTime.parse(chain.first.clientTime),
          events: events,
        ),
  ];

  @override
  Future<List<UploadState>> uploadStates() async => [
    for (final MapEntry(key: matchId, value: chain) in _events.entries)
      UploadState(
        matchId: matchId,
        gameId: _games[matchId]!,
        status: _status[matchId]!,
        lastSeq: chain.length - 1,
        ackedSeq: _acked[matchId] ?? -1,
      ),
  ];

  @override
  Future<List<EventEnvelope>> eventsFrom(
    String matchId,
    int fromSeq, {
    int limit = ServerApi.maxBatchEvents,
  }) async => [
    for (final event in _events[matchId] ?? const <EventEnvelope>[])
      if (event.seq >= fromSeq) event,
  ].take(limit).toList();

  @override
  Future<void> markAcked(String matchId, int seq) async {
    if (seq > (_acked[matchId] ?? -1)) _acked[matchId] = seq;
  }

  @override
  Future<void> settle(MatchSummary summary) async {
    _events.remove(summary.matchId);
    _status.remove(summary.matchId);
    _games.remove(summary.matchId);
    _acked.remove(summary.matchId);
    _summaries
      ..removeWhere((s) => s.matchId == summary.matchId)
      ..add(summary);
  }

  @override
  Future<List<MatchSummary>> summaries({int limit = 20}) async => (List.of(
    _summaries,
  )..sort((a, b) => b.settledAt.compareTo(a.settledAt))).take(limit).toList();

  /// The status of [matchId], for tests.
  MatchStatus? statusOf(String matchId) => _status[matchId];

  /// How far the server has acknowledged [matchId], for tests.
  int ackedOf(String matchId) => _acked[matchId] ?? -1;

  /// Puts [event] in place of the event with its `seq`, as a tampered
  /// device might. For tests.
  void replaceForTest(EventEnvelope event) =>
      _events[event.matchId]![event.seq] = event;
}
