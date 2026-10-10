import 'package:bots/bots.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/remote/auth_repository.dart';
import 'package:card_games/data/remote/game_server.dart';
import 'package:card_games/data/sync/sync_engine.dart';
import 'package:card_games/data/wallet.dart';
import 'package:card_games/features/games/twentynine/offline_match.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../helpers/fake_server.dart';
import '../helpers/test_app.dart';

/// A log for a guest profile with UUIDs, as the app makes them.
MemoryEventLog newLog() => MemoryEventLog(
  identity: LocalIdentity(deviceId: uuidV7(), userId: uuidV7()),
);

/// Plays a match in [log] with the app's own controller, the player's moves
/// chosen by a Skilled bot. Stops after [actions] of the player's actions,
/// if given; otherwise plays to the end and votes to end the game, so the
/// match is complete (AGENTS.md §6.13). Returns the match ID.
Future<String> play(MemoryEventLog log, {int stake = 500, int? actions}) async {
  final container = ProviderContainer.test(overrides: memoryOverrides(log));
  final controller = container.read(offlineMatchProvider.notifier);
  await controller.start(
    const TwentyNineConfig(),
    BotLevel.casual,
    stake: stake,
  );
  final matchId = container.read(offlineMatchProvider)!.matchId;
  var taken = 0;
  for (var step = 0; step < 20000; step++) {
    await pumpEventQueue();
    final table = container.read(offlineMatchProvider)!;
    if (table.view.phase == TwentyNinePhase.matchOver) {
      await controller.vote(continueGame: false);
      return matchId;
    }
    if (actions != null && taken >= actions) return matchId;
    if (table.dealResult != null) {
      controller.dismissDealResult();
    } else if (table.view.isMyTurn) {
      await controller.act(
        const DirectBotRunner().decide(table.view, BotLevel.skilled, step),
      );
      taken++;
    }
  }
  fail('the match did not end');
}

/// The coins [log]'s match earns by the shared rules.
Future<int> coinsOf(EventLog log, String matchId) async =>
    matchCoins(await log.events(matchId))
        .fold<int>(0, (sum, entry) => sum + entry.amount);

void main() {
  late FakeAuthRepository auth;
  late InProcessServer server;
  late RemoteSession guest;
  late SyncEngine engine;

  setUp(() async {
    auth = FakeAuthRepository();
    server = InProcessServer(auth);
    guest = await auth.signInAsGuest();
    engine = SyncEngine(server, batchSize: 50);
  });

  test('a finished match goes up in batches and is settled once', () async {
    final log = newLog();
    final matchId = await play(log);
    final coins = await coinsOf(log, matchId);
    final last = (await log.uploadStates()).single.lastSeq;

    final report = await engine.sync(log, guest.accessToken);
    expect(server.received.length, greaterThan(1), reason: 'several batches');
    expect(server.received.first, (matchId, 0, 49));
    expect(server.received.last.$3, last);
    expect(report.settled.single.matchId, matchId);
    expect(report.settled.single.coins, coins);
    expect(report.balance, 1000 + coins);
    expect(report.credited, [const CoinCredit(CoinReason.welcomeGift, 1000)]);
    expect(server.store.matchOf(matchId)!.status, MatchSyncStatus.accepted);
    expect(server.store.matchOf(matchId)!.coins, coins, reason: 'they agree');

    // Settled: the events are gone and a summary is kept (AGENTS.md §9).
    expect(await log.events(matchId), isEmpty);
    expect(await log.uploadStates(), isEmpty);
    final summary = (await log.summaries()).single;
    expect((summary.stake, summary.coins), (500, coins));
    expect(summary.result, isNot(SettledResult.rejected));

    final again = await engine.sync(log, guest.accessToken);
    expect(again.settled, isEmpty);
    expect(server.balanceOf(guest.userId), 1000 + coins);
  });

  test('a match being played goes up and waits for the rest', () async {
    final log = newLog();
    final matchId = await play(log, actions: 6);
    final state = (await log.uploadStates()).single;
    final report = await engine.sync(log, guest.accessToken);
    expect(report.waiting, 1);
    expect(log.ackedOf(matchId), state.lastSeq);
    expect(server.store.matchOf(matchId)!.status, MatchSyncStatus.open);
    final sent = server.uploads;
    await engine.sync(log, guest.accessToken);
    expect(server.uploads, sent, reason: 'nothing new to send');
  });

  group('AGENTS.md §9 cases', () {
    test('a lost answer: the batch is sent again and counted once', () async {
      final log = newLog();
      final matchId = await play(log);
      server.dropAnswers = 1;
      await expectLater(
        engine.sync(log, guest.accessToken),
        throwsA(isA<ServerUnavailable>()),
      );
      expect(log.ackedOf(matchId), -1, reason: 'the device never heard');
      await engine.sync(log, guest.accessToken);
      expect(server.received.first, server.received[1], reason: 'resent');
      final ledger = server.store.ledger.where((e) => e.userId == guest.userId);
      expect(
        ledger.map((e) => (e.reason, e.refId)).toSet(),
        hasLength(ledger.length),
        reason: 'nothing credited twice',
      );
      expect(await log.uploadStates(), isEmpty);
    });

    test('an interrupted sync resumes after what was acknowledged', () async {
      final log = newLog();
      final matchId = await play(log);
      server.goOfflineAfter = 2;
      await expectLater(
        engine.sync(log, guest.accessToken),
        throwsA(isA<ServerUnavailable>()),
      );
      expect(log.ackedOf(matchId), 99);
      server
        ..online = true
        ..goOfflineAfter = null;
      await engine.sync(log, guest.accessToken);
      expect(server.received[2].$2, 100, reason: 'resumed, not restarted');
      expect(await log.uploadStates(), isEmpty);
    });

    test(
      'when the server holds less, the upload restarts from there',
      () async {
        final log = newLog();
        final matchId = await play(log);
        // The device believes more was acknowledged than the server holds,
        // as after a batch that arrived out of order.
        await log.markAcked(matchId, 60);
        await engine.sync(log, guest.accessToken);
        expect(server.received.first.$2, 61);
        expect(server.received[1].$2, 0, reason: 'sent again from the start');
        expect(server.store.matchOf(matchId)!.status, MatchSyncStatus.accepted);
      },
    );

    test(
      'a tampered log is rejected, earns nothing and leaves the wallet',
      () async {
        final log = newLog();
        final matchId = await play(log);
        final events = await log.events(matchId);
        final fee = events[1];
        expect(fee.type, EventTypes.entryFee);
        log.replaceForTest(
          EventEnvelope(
            eventId: fee.eventId,
            matchId: fee.matchId,
            seq: fee.seq,
            type: fee.type,
            actor: fee.actor,
            payload: const {'stake': 100, 'seats': 4},
            clientTime: fee.clientTime,
            userId: fee.userId,
            deviceId: fee.deviceId,
            gameId: fee.gameId,
            rulesVersion: fee.rulesVersion,
            appVersion: fee.appVersion,
            prevHash: fee.prevHash,
            hash: fee.hash,
          ),
        );
        final report = await engine.sync(log, guest.accessToken);
        final summary = report.settled.single;
        expect((summary.result, summary.coins), (SettledResult.rejected, 0));
        expect(
          server.store.matchOf(matchId)!.reason,
          startsWith('broken hash'),
        );
        expect(report.balance, 1000, reason: 'only the gift');
        final wallet = await LocalWalletRepository(
          log,
          confirmed: () async => report.balance,
        ).load();
        expect(wallet.pending, isEmpty);
        expect(wallet.spendable, 1000);
        expect(wallet.history.single.result, SettledResult.rejected);
      },
    );
  });

  test('a practice match settles with no coins', () async {
    final log = newLog();
    await play(log, stake: 0);
    final report = await engine.sync(log, guest.accessToken);
    expect(report.settled.single.result, SettledResult.practice);
    expect(report.settled.single.coins, 0);
    expect(report.balance, 1000);
  });

  test(
    'a game of two matches settles each in turn (AGENTS.md §6.13)',
    () async {
      final log = newLog();
      final container = ProviderContainer.test(overrides: memoryOverrides(log));
      final controller = container.read(offlineMatchProvider.notifier);

      /// Plays the current match to its end; returns its ID.
      Future<String> finish() async {
        for (var step = 0; step < 20000; step++) {
          await pumpEventQueue();
          final TableState table = container.read(offlineMatchProvider)!;
          if (table.view.phase == TwentyNinePhase.matchOver) {
            return table.matchId;
          }
          if (table.dealResult != null) {
            controller.dismissDealResult();
          } else if (table.view.isMyTurn) {
            await controller.act(
              const DirectBotRunner().decide(
                table.view,
                BotLevel.skilled,
                step,
              ),
            );
          }
        }
        fail('the match did not end');
      }

      await controller.start(
        const TwentyNineConfig(),
        BotLevel.casual,
        stake: 100,
      );
      final first = await finish();
      await controller.vote(continueGame: true);
      final firstCoins = await coinsOf(log, first);

      // Mid-game: the first match is complete; the second is being played.
      var report = await engine.sync(log, guest.accessToken);
      expect(report.settled.map((s) => s.matchId), [first]);
      expect(report.waiting, 1);
      expect(server.store.matchOf(first)!.seriesContinues, isTrue);

      final second = await finish();
      await controller.vote(continueGame: false);
      final secondCoins = await coinsOf(log, second);
      report = await engine.sync(log, guest.accessToken);
      expect(report.settled.map((s) => s.matchId), [second]);
      expect(report.settled.single.coins, secondCoins);
      expect(report.balance, 1000 + firstCoins + secondCoins);
      expect(server.store.matchOf(second)!.recordAfter, isNotNull);
    },
  );
}
