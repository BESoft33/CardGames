import 'package:sync_protocol/sync_protocol.dart';

import '../event_log.dart';
import '../local_database.dart';
import '../remote/game_server.dart';

/// What one sync run did.
final class SyncReport {
  /// Creates a report.
  const SyncReport({
    required this.balance,
    this.credited = const [],
    this.settled = const [],
    this.waiting = 0,
  });

  /// The confirmed balance afterwards.
  final int balance;

  /// One-off credits paid during it, such as the starting gift.
  final List<CoinCredit> credited;

  /// Matches the server settled during it.
  final List<MatchSummary> settled;

  /// Matches still waiting: being played, or not fully uploaded.
  final int waiting;
}

/// Uploads a profile's event log to the game server (AGENTS.md §9).
///
/// Each match goes up in `seq` order, in batches of at most 200 events,
/// starting after the last `seq` the server acknowledged; if the server
/// answers that it holds less, the upload resumes from there. A match the
/// server accepts or rejects is settled: its events are deleted and a
/// summary is kept. Network failures end the run with [ServerUnavailable];
/// nothing is lost, and the next run picks up where this one stopped.
final class SyncEngine {
  /// An engine uploading to [server], [batchSize] events at a time.
  SyncEngine(
    this.server, {
    this.batchSize = ServerApi.maxBatchEvents,
    DateTime Function()? clock,
  }) : assert(batchSize > 0 && batchSize <= ServerApi.maxBatchEvents),
       _clock = clock ?? DateTime.now;

  /// The game server.
  final GameServer server;

  /// The most events sent at once: at most 200 (AGENTS.md §9).
  final int batchSize;

  final DateTime Function() _clock;

  /// Syncs [log] with [accessToken], an account's valid token.
  Future<SyncReport> sync(EventLog log, String accessToken) async {
    final wallet = await server.wallet(accessToken);
    var balance = wallet.balance;
    final settled = <MatchSummary>[];
    var waiting = 0;
    for (final state in await log.uploadStates()) {
      final ack = await _upload(log, state, accessToken);
      if (ack == null) {
        waiting++;
        continue;
      }
      balance = ack.wallet.balance;
      if (ack.status == MatchSyncStatus.open) {
        waiting++;
      } else {
        settled.add(await _settle(log, state, ack.status));
      }
    }
    return SyncReport(
      balance: balance,
      credited: wallet.credited,
      settled: settled,
      waiting: waiting,
    );
  }

  /// Sends what the server lacks of [state]'s match. Returns the last
  /// answer, or null if there was nothing to send.
  Future<SyncAck?> _upload(
    EventLog log,
    UploadState state,
    String accessToken,
  ) async {
    var acked = state.ackedSeq;
    SyncAck? last;
    var stalled = 0;
    while (stalled < 2) {
      var batch = await log.eventsFrom(
        state.matchId,
        acked + 1,
        limit: batchSize,
      );
      if (batch.isEmpty) {
        // All sent. A match still being played waits for more; a finished
        // one whose verdict was lost sends its last event again, which the
        // server ignores but answers.
        if (state.status == MatchStatus.active || last != null) return last;
        batch = await log.eventsFrom(state.matchId, state.lastSeq);
        if (batch.isEmpty) return null;
      }
      final ack = await server.upload(
        UploadBatch(matchId: state.matchId, events: batch),
        accessToken,
      );
      last = ack;
      if (ack.status != MatchSyncStatus.open) return ack;
      if (ack.ackedSeq > acked) {
        await log.markAcked(state.matchId, ack.ackedSeq);
        stalled = 0;
      } else {
        stalled++;
      }
      // The server may hold less than this device thought, for example
      // after a batch arrived out of order: resume after what it holds.
      acked = ack.ackedSeq;
    }
    return last;
  }

  /// Settles a match the server has [status]: deletes its events and keeps
  /// a summary, with the coins the shared rules give its log.
  Future<MatchSummary> _settle(
    EventLog log,
    UploadState state,
    MatchSyncStatus status,
  ) async {
    final events = await log.events(state.matchId);
    final stake = events.isEmpty
        ? 0
        : (events.first.payload['stake'] as int?) ?? 0;
    final List<CoinEntry> coins;
    try {
      coins = status == MatchSyncStatus.accepted ? matchCoins(events) : [];
    } on FormatException {
      return _store(log, state, stake, SettledResult.rejected, 0);
    }
    // Coins tell staked results apart without knowing the game (AGENTS.md
    // §5.9); a practice match is only known to have been played.
    final SettledResult result;
    if (status == MatchSyncStatus.rejected) {
      result = SettledResult.rejected;
    } else if (coins.any((c) => c.reason == CoinReason.matchWon)) {
      result = SettledResult.won;
    } else if (stake == 0) {
      result = SettledResult.practice;
    } else if (state.status == MatchStatus.abandoned) {
      result = SettledResult.left;
    } else {
      result = SettledResult.lost;
    }
    return _store(
      log,
      state,
      stake,
      result,
      coins.fold(0, (sum, entry) => sum + entry.amount),
    );
  }

  Future<MatchSummary> _store(
    EventLog log,
    UploadState state,
    int stake,
    SettledResult result,
    int coins,
  ) async {
    final summary = MatchSummary(
      matchId: state.matchId,
      gameId: state.gameId,
      stake: stake,
      result: result,
      coins: coins,
      settledAt: _clock().toUtc(),
    );
    await log.settle(summary);
    return summary;
  }
}
