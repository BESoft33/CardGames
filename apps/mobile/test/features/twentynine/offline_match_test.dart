import 'package:bots/bots.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/wallet.dart';
import 'package:card_games/features/games/twentynine/offline_match.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/test_app.dart';

/// A container whose storage is in memory and whose bots decide
/// in-process and without any pause.
ProviderContainer containerWith(EventLog log) =>
    ProviderContainer.test(overrides: memoryOverrides(log));

/// Plays the player's turns with [random] legal actions until [stop] holds
/// or the match ends.
Future<void> playUntil(
  ProviderContainer container,
  Xoshiro256StarStar random, {
  bool Function(TableState table)? stop,
}) async {
  final controller = container.read(offlineMatchProvider.notifier);
  for (var step = 0; step < 20000; step++) {
    await pumpEventQueue();
    final table = container.read(offlineMatchProvider)!;
    if (table.view.phase == TwentyNinePhase.matchOver) return;
    if (stop != null && stop(table)) return;
    if (table.dealResult != null) {
      controller.dismissDealResult();
    } else if (table.view.isMyTurn) {
      final legal = table.view.legalActions;
      await controller.act(legal[random.nextBounded(legal.length)]);
    }
  }
  fail('the match did not end');
}

void main() {
  test('plays a whole match against bots, logging every event', () async {
    final log = MemoryEventLog();
    final container = containerWith(log);
    await container
        .read(offlineMatchProvider.notifier)
        .start(const TwentyNineConfig(), BotLevel.casual);
    final matchId = container.read(offlineMatchProvider)!.matchId;
    await playUntil(container, Xoshiro256StarStar.seeded(1));

    final table = container.read(offlineMatchProvider)!;
    expect(table.view.phase, TwentyNinePhase.matchOver);
    // The last deal's result came first; the match is over once it is seen.
    expect(table.dealResult, isNull);
    expect(table.matchEnded, isTrue);
    final events = await log.events(matchId);
    expect(verifyChain(events), isNull);
    expect(events.first.type, EventTypes.matchCreated);
    expect(events.first.payload['seats'], hasLength(4));
    expect(SeriesRef.fromCreated(events.first.payload).match, 1);
    expect(events.last.type, 'twentynine.matchEnded');
    // The match waits for the vote (AGENTS.md §6.13).
    expect(table.voting, isTrue);
    expect(log.statusOf(matchId), MatchStatus.active);
    expect(await log.unfinishedMatch('twentynine'), matchId);
    // Every seat acted, the player included.
    expect(
      events.map((e) => e.actor).toSet(),
      containsAll(['seat:0', 'seat:1', 'seat:2', 'seat:3', 'system', 'user']),
    );
  });

  test('the target is fixed at 6 (AGENTS.md §6.2)', () async {
    final log = MemoryEventLog();
    final container = containerWith(log);
    final controller = container.read(offlineMatchProvider.notifier);

    await expectLater(
      controller.start(
        const TwentyNineConfig(targetGamePoints: 3),
        BotLevel.casual,
      ),
      throwsArgumentError,
    );
    expect(container.read(offlineMatchProvider), isNull);
    expect(await log.unfinishedMatch(TwentyNineGame.gameId), isNull);

    await controller.start(const TwentyNineConfig(), BotLevel.casual);
    final created = (await log.events(
      container.read(offlineMatchProvider)!.matchId,
    )).first;
    expect(
      (created.payload['rules']! as Map)['targetGamePoints'] ?? 6,
      TwentyNineConfig.fixedTargetGamePoints,
    );
  });

  test('the player only sees their own view', () async {
    final container = containerWith(MemoryEventLog());
    await container
        .read(offlineMatchProvider.notifier)
        .start(const TwentyNineConfig(), BotLevel.beginner);
    final table = container.read(offlineMatchProvider)!;
    expect(table.view.seat, OfflineMatchController.player);
    expect(table.bots.keys, [const Seat(1), const Seat(2), const Seat(3)]);
    expect(table.bots.values.toSet(), {BotLevel.beginner});
  });

  test('ignores actions that are not the player\'s to take', () async {
    final log = MemoryEventLog();
    final container = containerWith(log);
    final controller = container.read(offlineMatchProvider.notifier);
    await controller.start(const TwentyNineConfig(), BotLevel.casual);
    await pumpEventQueue();
    final before = container.read(offlineMatchProvider)!;
    final matchId = before.matchId;
    final count = (await log.events(matchId)).length;
    await controller.act(const Bid(Seat(2), 16));
    await controller.act(const Bid(Seat(0), 99));
    expect((await log.events(matchId)).length, count);
  });

  test('waits for the player to see a deal\'s result', () async {
    final container = containerWith(MemoryEventLog());
    final controller = container.read(offlineMatchProvider.notifier);
    await controller.start(const TwentyNineConfig(), BotLevel.casual);
    await playUntil(
      container,
      Xoshiro256StarStar.seeded(2),
      stop: (table) => table.dealResult != null,
    );
    final waiting = container.read(offlineMatchProvider)!;
    await pumpEventQueue();
    final still = container.read(offlineMatchProvider)!;
    expect(still.dealResult, waiting.dealResult);
    expect(
      canonicalJson(still.view.toJson()),
      canonicalJson(waiting.view.toJson()),
      reason: 'nobody plays while the result is on screen',
    );
    controller.dismissDealResult();
    expect(container.read(offlineMatchProvider)!.dealResult, isNull);
  });

  test('a deal ends on screen before the next is dealt: last trick, '
      'then result, then new cards', () async {
    const pause = Duration(milliseconds: 60);
    final container = ProviderContainer.test(
      overrides: memoryOverrides(MemoryEventLog(), dealEnd: pause),
    );
    final controller = container.read(offlineMatchProvider.notifier);
    await controller.start(const TwentyNineConfig(), BotLevel.casual);
    final random = Xoshiro256StarStar.seeded(4);
    late TableState ending;
    for (var step = 0; ; step++) {
      expect(step, lessThan(20000), reason: 'a deal should end');
      await pumpEventQueue();
      final TableState table = container.read(offlineMatchProvider)!;
      if (table.view.tricks.length == 8) {
        ending = table;
        break;
      }
      if (table.view.isMyTurn) {
        final legal = table.view.legalActions;
        await controller.act(legal[random.nextBounded(legal.length)]);
      }
    }
    // The finished deal, its last trick on the table, and no result yet.
    expect(ending.dealResult, isNull);
    expect(ending.view.trick, isEmpty);
    expect(ending.view.tricks.last.plays, hasLength(4));
    expect(ending.view.hand, isEmpty, reason: 'every card was played');
    expect(ending.view.isMyTurn, isFalse);
    controller.dismissDealResult();
    expect(container.read(offlineMatchProvider)!.view.tricks, hasLength(8));

    await Future<void>.delayed(pause * 2);
    final TableState result = container.read(offlineMatchProvider)!;
    expect(result.dealResult, isNotNull);
    expect(result.view.dealNumber, ending.view.dealNumber);
    expect(result.view.scores, result.dealResult!.scores);

    controller.dismissDealResult();
    final TableState next = container.read(offlineMatchProvider)!;
    expect(next.dealResult, isNull);
    if (!next.matchEnded) {
      expect(next.view.tricks, isEmpty);
      expect(next.view.hand, hasLength(4), reason: 'the new cards come now');
      expect(next.view.dealNumber, ending.view.dealNumber + 1);
    }
  });

  test('resumes an interrupted match from the event log', () async {
    final log = MemoryEventLog();
    final first = containerWith(log);
    await first
        .read(offlineMatchProvider.notifier)
        .start(const TwentyNineConfig(), BotLevel.skilled);
    await playUntil(
      first,
      Xoshiro256StarStar.seeded(3),
      stop: (table) => table.view.tricks.length >= 3,
    );
    await pumpEventQueue();
    final interrupted = first.read(offlineMatchProvider)!;

    final second = containerWith(log);
    final controller = second.read(offlineMatchProvider.notifier);
    expect(await log.unfinishedMatch('twentynine'), interrupted.matchId);
    expect(await controller.resume(interrupted.matchId), isTrue);
    final resumed = second.read(offlineMatchProvider)!;
    expect(
      canonicalJson(resumed.view.toJson()),
      canonicalJson(interrupted.view.toJson()),
    );
    expect(resumed.bots, interrupted.bots);
  });

  test('a broken log is not resumed', () async {
    final log = MemoryEventLog();
    await log.append(
      'broken',
      const [
        NewEvent('twentynine.bid', 'seat:0', {'value': 16}),
      ],
      gameId: 'twentynine',
      rulesVersion: 1,
    );
    final container = containerWith(log);
    expect(
      await container.read(offlineMatchProvider.notifier).resume('broken'),
      isFalse,
    );
    expect(log.statusOf('broken'), MatchStatus.abandoned);
    expect(container.read(offlineMatchProvider), isNull);
  });

  test('leaving a match in play quits the game, logging the score', () async {
    final log = MemoryEventLog();
    final container = containerWith(log);
    final controller = container.read(offlineMatchProvider.notifier);
    await controller.start(const TwentyNineConfig(), BotLevel.casual);
    final matchId = container.read(offlineMatchProvider)!.matchId;
    await controller.leave();
    expect(container.read(offlineMatchProvider), isNull);
    final events = await log.events(matchId);
    final tail = events.skip(events.length - 2).toList();
    expect(tail.map((e) => e.type), [
      EventTypes.matchAbandoned,
      EventTypes.seriesEnded,
    ]);
    expect(tail.first.payload, SeriesPayloads.abandoned(score: 0));
    expect(tail.last.payload, SeriesPayloads.ended(SeriesEnd.quit, record: 0));
    expect(verifyChain(events), isNull);
    expect(log.statusOf(matchId), MatchStatus.abandoned);
  });

  group('games (AGENTS.md §6.13)', () {
    /// Plays the current match to its end, the player's moves chosen by a
    /// Skilled bot from [seed], so that both sides win often enough.
    Future<TableState> finish(ProviderContainer container, int seed) async {
      final controller = container.read(offlineMatchProvider.notifier);
      for (var step = 0; step < 20000; step++) {
        await pumpEventQueue();
        final TableState table = container.read(offlineMatchProvider)!;
        if (table.view.phase == TwentyNinePhase.matchOver) return table;
        if (table.dealResult != null) {
          controller.dismissDealResult();
        } else if (table.view.isMyTurn) {
          await controller.act(
            const DirectBotRunner().decide(
              table.view,
              BotLevel.skilled,
              seed * 100000 + step,
            ),
          );
        }
      }
      fail('the match did not end');
    }

    test('playing on starts the next match, the record carried', () async {
      final log = MemoryEventLog();
      final container = containerWith(log);
      final controller = container.read(offlineMatchProvider.notifier);
      await controller.start(const TwentyNineConfig(), BotLevel.casual);
      final first = await finish(container, 1);
      final won = first.view.winningTeam == 0;
      expect(first.record, won ? 1 : -1);

      await controller.vote(continueGame: true);
      final second = container.read(offlineMatchProvider)!;
      expect(second.matchId, isNot(first.matchId));
      expect(second.view.phase, isNot(TwentyNinePhase.matchOver));
      expect(second.series!.id, first.series!.id);
      expect((second.series!.match, second.record), (2, first.record));
      final firstEvents = await log.events(first.matchId);
      expect(firstEvents.last.type, EventTypes.seriesVote);
      expect(firstEvents.last.payload, {'continue': true});
      expect(log.statusOf(first.matchId), MatchStatus.finished);
      final created = (await log.events(second.matchId)).first;
      // The others reaching -6 puts the card on their side, in black.
      final endedByLoss = first.view.scores[won ? 1 : 0] <= -6;
      expect(
        SeriesRef.fromCreated(created.payload),
        first.series!.next(won: won, endedByLoss: endedByLoss),
      );
      expect(second.trailing, endedByLoss);
      expect(await log.unfinishedMatch('twentynine'), second.matchId);
    });

    test('ending the game after a match closes it, with the record', () async {
      final log = MemoryEventLog();
      final container = containerWith(log);
      final controller = container.read(offlineMatchProvider.notifier);
      await controller.start(const TwentyNineConfig(), BotLevel.casual);
      final over = await finish(container, 2);

      await controller.vote(continueGame: false);
      final ended = container.read(offlineMatchProvider)!;
      expect(ended.gameEnd, SeriesEnd.vote);
      expect(ended.voting, isFalse);
      final events = await log.events(over.matchId);
      expect(events.last.payload, {'reason': 'vote', 'record': over.record});
      expect(log.statusOf(over.matchId), MatchStatus.finished);
      expect(await log.unfinishedMatch('twentynine'), isNull);
      await controller.vote(continueGame: true);
      expect(
        container.read(offlineMatchProvider)!.matchId,
        over.matchId,
        reason: 'a game that ended takes no more votes',
      );
    });

    test('a lost match adds the penalty after the vote, either way', () async {
      for (var seed = 1; seed < 60; seed++) {
        final log = MemoryEventLog();
        final container = containerWith(log);
        final controller = container.read(offlineMatchProvider.notifier);
        await controller.start(
          const TwentyNineConfig(),
          BotLevel.casual,
          stake: 100,
        );
        final over = await finish(container, seed);
        if (over.view.winningTeam == 0) continue;
        expect(
          (await log.events(over.matchId)).map((e) => e.type),
          isNot(contains(EventTypes.penaltyPending)),
          reason: 'not before the vote',
        );
        await controller.vote(continueGame: false);
        final types = [for (final e in await log.events(over.matchId)) e.type];
        expect(types.skip(types.length - 3), [
          EventTypes.seriesVote,
          EventTypes.penaltyPending,
          EventTypes.seriesEnded,
        ]);
        final pending = (await LocalWalletRepository(
          log,
        ).load()).pending.whereType<PendingMatch>().single;
        expect(
          pending.entries.last,
          const CoinEntry(CoinReason.lossPenalty, -50),
        );
        return;
      }
      fail('no such match was played');
    });

    test('playing on needs the next fee after the penalty', () async {
      for (var seed = 1; seed < 60; seed++) {
        final log = MemoryEventLog();
        final container = containerWith(log);
        final controller = container.read(offlineMatchProvider.notifier);
        await controller.start(
          const TwentyNineConfig(),
          BotLevel.casual,
          stake: 1000,
        );
        final over = await finish(container, seed);
        if (over.view.winningTeam == 0) continue;
        // 1,000 - 1,000, at most 16 deal bonuses of 50, then a 500 EC
        // penalty: never another 1,000.
        await expectLater(
          controller.vote(continueGame: true),
          throwsA(isA<NotEnoughCoins>()),
        );
        expect(
          (await log.events(over.matchId)).last.type,
          'twentynine.matchEnded',
          reason: 'nothing is logged',
        );
        expect(container.read(offlineMatchProvider)!.voting, isTrue);
        await controller.vote(continueGame: false);
        expect(container.read(offlineMatchProvider)!.gameEnd, SeriesEnd.vote);
        return;
      }
      fail('no such match was played');
    });

    test('a game ended level refunds every fee; winnings stay', () async {
      for (var seed = 1; seed < 60; seed++) {
        final log = MemoryEventLog();
        final container = containerWith(log);
        final controller = container.read(offlineMatchProvider.notifier);
        await controller.start(
          const TwentyNineConfig(),
          BotLevel.casual,
          stake: 100,
        );
        final first = await finish(container, seed);
        await controller.vote(continueGame: true);
        final second = await finish(container, seed + 1000);
        if (second.record != 0) continue;
        await controller.vote(continueGame: false);
        final events = await log.events(second.matchId);
        final refund = events.singleWhere(
          (e) => e.payload['reason'] == 'tieRefund',
        );
        expect(refund.payload['matches'], 2);
        final wallet = await LocalWalletRepository(log).load();
        final matches = wallet.pending.whereType<PendingMatch>().toList();
        expect(matches.map((m) => m.matchId), [second.matchId, first.matchId]);
        expect(
          matches.first.entries,
          contains(const CoinEntry(CoinReason.tieRefund, 200)),
        );
        expect(container.read(offlineMatchProvider)!.gameEnd, SeriesEnd.vote);
        return;
      }
      fail('no such match was played');
    });

    test('a match over before the vote resumes at the vote', () async {
      final log = MemoryEventLog();
      final first = containerWith(log);
      await first
          .read(offlineMatchProvider.notifier)
          .start(const TwentyNineConfig(), BotLevel.casual);
      final over = await finish(first, 4);

      final second = containerWith(log);
      final controller = second.read(offlineMatchProvider.notifier);
      expect(await controller.resume(over.matchId), isTrue);
      final resumed = second.read(offlineMatchProvider)!;
      expect(resumed.voting, isTrue);
      expect(resumed.record, over.record);
      await controller.vote(continueGame: true);
      expect(second.read(offlineMatchProvider)!.series!.match, 2);
    });

    test('the match played with a 2 showing ends the game', () async {
      final log = MemoryEventLog();
      const series = SeriesRef(
        id: '0199c4a0-0000-7000-8000-0000000000e9',
        match: 5,
        record: 4,
      );
      // A match logged as the app logs it, at this place in its game.
      const game = TwentyNineGame();
      final first = game.init(const TwentyNineConfig().toMatchConfig(), 7);
      await log.append(
        'last',
        [
          NewEvent(EventTypes.matchCreated, Actors.user, {
            'rules': const TwentyNineConfig().toJson(),
            'seed': seedToHex(7),
            'stake': 0,
            'seats': [
              {'seat': 0, 'player': 'human'},
              for (final seat in [1, 2, 3])
                {'seat': seat, 'player': 'bot', 'level': 'casual'},
            ],
            'series': series.toJson(),
          }),
          for (final event in first.lastEvents)
            NewEvent(
              event.type,
              event.actor?.id ?? Actors.system,
              event.payload,
            ),
        ],
        gameId: 'twentynine',
        rulesVersion: 1,
      );
      final container = containerWith(log);
      final controller = container.read(offlineMatchProvider.notifier);
      expect(await controller.resume('last'), isTrue);
      expect(container.read(offlineMatchProvider)!.series!.isLastMatch, isTrue);
      final over = await finish(container, 9);

      expect(over.gameEnd, SeriesEnd.lastMatch);
      expect(over.voting, isFalse);
      final events = await log.events('last');
      expect(events.map((e) => e.type), isNot(contains(EventTypes.seriesVote)));
      expect(events.last.payload, {
        'reason': 'lastMatch',
        'record': over.record,
      });
      expect(log.statusOf('last'), MatchStatus.finished);
    });
  });

  group('coins (docs/decisions.md D-024)', () {
    /// The team that won a logged deal: the bidding team if it made its
    /// contract, the other team if it failed, nobody if the deal was void.
    int? winnerOf(Map<String, Object?> scored) {
      final team = scored['team']! as int;
      return switch (scored['outcome']) {
        'contractMade' || 'singleHandWon' => team,
        'contractFailed' || 'singleHandLost' => 1 - team,
        _ => null,
      };
    }

    /// Plays the match to its end, the player's moves chosen by a Skilled
    /// bot so that their side wins often enough.
    Future<void> playWell(ProviderContainer container) async {
      final controller = container.read(offlineMatchProvider.notifier);
      for (var step = 0; step < 20000; step++) {
        await pumpEventQueue();
        final table = container.read(offlineMatchProvider)!;
        if (table.view.phase == TwentyNinePhase.matchOver) return;
        if (table.dealResult != null) {
          controller.dismissDealResult();
        } else if (table.view.isMyTurn) {
          await controller.act(
            const DirectBotRunner().decide(table.view, BotLevel.skilled, step),
          );
        }
      }
      fail('the match did not end');
    }

    // Deals and bots are random, so matches are played until one has been
    // won and one lost; each is checked against its own log.
    test('a staked match takes the fee and rewards each deal won', () async {
      final outcomes = <bool>{};
      var dealRewards = 0;
      for (var match = 0; match < 50 && outcomes.length < 2; match++) {
        final log = MemoryEventLog();
        final container = containerWith(log);
        await container
            .read(offlineMatchProvider.notifier)
            .start(const TwentyNineConfig(), BotLevel.casual, stake: 1000);
        final matchId = container.read(offlineMatchProvider)!.matchId;
        expect(container.read(offlineMatchProvider)!.stake, 1000);
        await playWell(container);

        final events = await log.events(matchId);
        expect(verifyChain(events), isNull);
        expect(events.first.payload['stake'], 1000);
        expect(events[1].type, EventTypes.entryFee);
        expect(events[1].payload, {'stake': 1000, 'seats': 4, 'humans': 1});

        // Deals the player's team won, by number, from the game's events.
        var deal = 0;
        final dealsWon = <int>[];
        for (final event in events) {
          if (event.type == 'twentynine.dealStarted') {
            deal = event.payload['dealNumber']! as int;
          } else if (event.type == 'twentynine.dealScored' &&
              winnerOf(event.payload) == 0) {
            dealsWon.add(deal);
          }
        }
        final rewards = [
          for (final event in events)
            if (event.type == EventTypes.rewardPending) event.payload,
        ];
        expect([
          for (final reward in rewards)
            if (reward['reason'] == 'dealWon') reward['deal'],
        ], dealsWon);
        final ended = events.singleWhere(
          (e) => e.type == 'twentynine.matchEnded',
        );
        final won = ended.payload['winningTeam'] == 0;
        expect(
          rewards.where((reward) => reward['reason'] == 'matchWon'),
          won ? [EconomyPayloads.matchWon(winners: 1)] : isEmpty,
        );

        await container
            .read(offlineMatchProvider.notifier)
            .vote(continueGame: false);
        final wallet = await LocalWalletRepository(log).load();
        final pending = wallet.pending.whereType<PendingMatch>().single;
        // A loss adds a quarter of the 2,000 EC pot (D-024).
        expect(
          pending.amount,
          -1000 + 50 * dealsWon.length + (won ? 2000 : -500),
        );
        expect((pending.status, pending.won), (MatchStatus.finished, won));
        expect(
          (await container.read(walletProvider.future)).spendable,
          wallet.spendable,
          reason: 'the wallet the screens watch is up to date',
        );
        outcomes.add(won);
        dealRewards += dealsWon.length;
      }
      expect(outcomes, {true, false}, reason: 'a win and a loss were seen');
      expect(dealRewards, isPositive);
    });

    test('a practice match moves no coins', () async {
      final log = MemoryEventLog();
      final container = containerWith(log);
      await container
          .read(offlineMatchProvider.notifier)
          .start(const TwentyNineConfig(), BotLevel.casual);
      final matchId = container.read(offlineMatchProvider)!.matchId;
      expect(container.read(offlineMatchProvider)!.stake, 0);
      await playUntil(container, Xoshiro256StarStar.seeded(5));
      final events = await log.events(matchId);
      expect(events.first.payload['stake'], 0);
      expect(events.where((e) => e.type.startsWith('economy.')), isEmpty);
      expect((await LocalWalletRepository(log).load()).spendable, 1000);
    });

    test('a staked match needs the fee', () async {
      final log = MemoryEventLog();
      final container = containerWith(log);
      final controller = container.read(offlineMatchProvider.notifier);
      await controller.start(
        const TwentyNineConfig(),
        BotLevel.casual,
        stake: 1000,
      );
      final first = container.read(offlineMatchProvider)!.matchId;
      // The gift has gone on the first fee; nothing is left to pay with.
      await expectLater(
        controller.start(const TwentyNineConfig(), BotLevel.casual, stake: 100),
        throwsA(
          isA<NotEnoughCoins>()
              .having((e) => e.stake, 'stake', 100)
              .having((e) => e.spendable, 'spendable', 0),
        ),
      );
      expect(log.statusOf(first), MatchStatus.active, reason: 'still there');
      expect(container.read(offlineMatchProvider)?.matchId, first);
      expect(
        () => controller.start(
          const TwentyNineConfig(),
          BotLevel.casual,
          stake: 999,
        ),
        throwsArgumentError,
      );
    });

    test('a new game quits the unfinished match: half the pot back', () async {
      final log = MemoryEventLog();
      final container = containerWith(log);
      final controller = container.read(offlineMatchProvider.notifier);
      await controller.start(
        const TwentyNineConfig(),
        BotLevel.casual,
        stake: 500,
      );
      final first = container.read(offlineMatchProvider)!.matchId;
      await controller.start(const TwentyNineConfig(), BotLevel.casual);
      final second = container.read(offlineMatchProvider)!.matchId;
      expect(second, isNot(first));
      expect(log.statusOf(first), MatchStatus.abandoned);
      expect((await log.events(first)).last.type, EventTypes.seriesEnded);
      expect(await log.unfinishedMatch('twentynine'), second);
      final wallet = await LocalWalletRepository(log).load();
      final left = wallet.pending.whereType<PendingMatch>().single;
      expect((left.matchId, left.status), (first, MatchStatus.abandoned));
      expect(left.entries.last, const CoinEntry(CoinReason.quitRefund, 500));
      expect(
        wallet.spendable,
        1000,
        reason: 'at 0 points, quitting returns half of the 1,000 EC pot',
      );
    });

    test('resuming keeps the stake; quitting level returns the fee', () async {
      final log = MemoryEventLog();
      final first = containerWith(log);
      await first
          .read(offlineMatchProvider.notifier)
          .start(const TwentyNineConfig(), BotLevel.casual, stake: 500);
      final matchId = first.read(offlineMatchProvider)!.matchId;

      final second = containerWith(log);
      final controller = second.read(offlineMatchProvider.notifier);
      expect(await controller.resume(matchId), isTrue);
      expect(second.read(offlineMatchProvider)!.stake, 500);
      await controller.leave();
      expect(log.statusOf(matchId), MatchStatus.abandoned);
      final wallet = await second.read(walletProvider.future);
      expect(wallet.spendable, 1000);
    });
  });
}
