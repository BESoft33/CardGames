import 'package:cardgames_server/cardgames_server.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const TwentyNineReplayer replayer = TwentyNineReplayer();

ReplayOutcome replayOf(List<Raw> events) => replayer.replay(chain(events));

/// The reason [events] are refused, failing if they are not.
String refusal(List<Raw> events) => switch (replayOf(events)) {
  ReplayRejected(:final reason) => reason,
  final other => fail('expected a rejection, got $other'),
};

/// [events] with the event at [index] replaced by [replacement].
List<Raw> swap(List<Raw> events, int index, Raw replacement) => [
  ...events.take(index),
  replacement,
  ...events.skip(index + 1),
];

void main() {
  final wonSeed = seedWhere(won: true);
  final won = playMatch(seed: wonSeed, stake: 1000);

  test('a whole match replays, complete, with its coins', () {
    final outcome = replayOf(won);
    expect(outcome, isA<ReplayComplete>());
    final coins = (outcome as ReplayComplete).coins;
    expect(coins.first, const CoinEntry(CoinReason.entryFee, -1000));
    expect(coins.last, const CoinEntry(CoinReason.matchWon, 2000));
    expect(coins.where((c) => c.reason == CoinReason.dealWon), isNotEmpty);
  });

  test('every start of a valid log is open, even mid-step', () {
    for (var length = 0; length < won.length; length += 7) {
      expect(
        replayOf(won.take(length).toList()),
        isA<ReplayOpen>(),
        reason: 'the first $length events',
      );
    }
  });

  test('a match left early is complete; it keeps the deals won', () {
    final left = playMatch(seed: 3, stake: 500, actions: 40, abandon: true);
    final outcome = replayOf(left);
    expect(outcome, isA<ReplayComplete>());
    expect(
      (outcome as ReplayComplete).coins.first,
      const CoinEntry(CoinReason.entryFee, -500),
    );
    expect(
      outcome.coins.where((c) => c.reason == CoinReason.matchWon),
      isEmpty,
    );
  });

  test('practice moves no coins; a lost match costs the fee', () {
    final practice = replayOf(playMatch(seed: 4, stake: 0));
    expect((practice as ReplayComplete).coins, isEmpty);
    final lost = replayOf(playMatch(seed: seedWhere(won: false)));
    expect(
      (lost as ReplayComplete).coins.where(
        (c) => c.reason == CoinReason.matchWon,
      ),
      isEmpty,
    );
  });

  group('a changed log is rejected', () {
    int indexOf(String type, [int from = 0]) =>
        won.indexWhere((e) => e.type == type, from);

    test('a card that was not legal', () {
      final i = indexOf('twentynine.cardPlayed');
      final played = won[i];
      final other = played.payload['card'] == 'JS' ? 'JH' : 'JS';
      expect(
        refusal(swap(won, i, raw(played.type, played.actor, {'card': other}))),
        anyOf(startsWith('illegal action'), contains('should be')),
      );
    });

    test('a trick credited to the wrong player', () {
      final i = indexOf('twentynine.trickWon');
      final trick = won[i];
      final winner = trick.payload['winner']! as int;
      expect(
        refusal(
          swap(
            won,
            i,
            raw(trick.type, trick.actor, {
              ...trick.payload,
              'winner': (winner + 1) % 4,
            }),
          ),
        ),
        contains('should be twentynine.trickWon'),
      );
    });

    test('a reward the rules did not give, or one left out', () {
      final i = indexOf(EventTypes.rewardPending);
      expect(refusal(swap(won, i, won[i - 1])), contains('should be'));
      final extra = [
        ...won.take(5),
        raw(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.matchWon(winners: 2),
        ),
        ...won.skip(5),
      ];
      // Refused where it stands: inside a step, or between two.
      expect(
        refusal(extra),
        anyOf(contains('should be'), contains('unexpected event')),
      );
      expect(
        refusal([...won.take(i), ...won.skip(i + 1)]),
        contains('should be'),
      );
    });

    test('a stake that is not a table fee, or a missing fee', () {
      final created = won.first;
      expect(
        refusal(
          swap(
            won,
            0,
            raw(created.type, created.actor, {
              ...created.payload,
              'stake': 999,
            }),
          ),
        ),
        'match.created names no table fee',
      );
      expect(refusal([won.first, ...won.skip(2)]), contains('should be'));
    });

    test('a target other than the fixed 6 (AGENTS.md §6.2)', () {
      final created = won.first;
      expect(
        refusal(
          swap(
            won,
            0,
            raw(created.type, created.actor, {
              ...created.payload,
              'rules': const TwentyNineConfig(targetGamePoints: 3).toJson(),
            }),
          ),
        ),
        'the target is fixed at 6',
      );
    });

    test('events after the end, or after leaving', () {
      expect(refusal([...won, won.last]), 'events follow the end of the game');
      final left = playMatch(seed: 3, actions: 30, abandon: true);
      expect(
        refusal([...left, left[left.length - 2]]),
        'events follow the end of the game',
      );
    });

    test('a log that does not start with match.created', () {
      expect(
        refusal(won.skip(1).toList()),
        'the log does not start with match.created',
      );
      final created = won.first;
      expect(
        refusal(
          swap(
            won,
            0,
            raw(created.type, created.actor, {
              ...created.payload,
              'seats': [
                for (final seat in [0, 1, 2, 3])
                  {'seat': seat, 'player': 'bot', 'level': 'casual'},
              ],
            }),
          ),
        ),
        'no seat is the player',
      );
    });

    test('an event no rule knows', () {
      expect(
        refusal([...won.take(12), raw('twentynine.cheated', 'seat:0')]),
        anyOf(startsWith('unexpected event'), contains('should be')),
      );
    });
  });

  group('games (AGENTS.md §6.13, docs/decisions.md D-037)', () {
    final lostSeed = seedWhere(won: false);
    const seriesTwo = '0199c4a0-0000-7000-8000-0000000000e2';

    ReplayComplete complete(List<Raw> events) {
      final outcome = replayOf(events);
      expect(outcome, isA<ReplayComplete>(), reason: '$outcome');
      return outcome as ReplayComplete;
    }

    List<CoinEntry> coinsFor(List<Raw> events, CoinReason reason) => [
      for (final coin in complete(events).coins)
        if (coin.reason == reason) coin,
    ];

    test('a match waits for the vote, which says whether the game goes on', () {
      final open = playMatch(seed: wonSeed, continueGame: null);
      expect(replayOf(open), isA<ReplayOpen>());

      final goOn = complete(playMatch(seed: wonSeed, continueGame: true));
      expect(
        (goOn.outcome, goOn.recordAfter, goOn.continues),
        (MatchOutcome.won, 1, true),
      );
      final stop = complete(playMatch(seed: wonSeed));
      expect(stop.continues, isFalse);
    });

    test('a lost match adds 25% of the pot, after the vote', () {
      final lost = playMatch(seed: lostSeed, stake: 1000, continueGame: true);
      expect(coinsFor(lost, CoinReason.lossPenalty), const [
        CoinEntry(CoinReason.lossPenalty, -500),
      ]);
      final outcome = complete(lost);
      expect((outcome.outcome, outcome.recordAfter), (MatchOutcome.lost, -1));
      // Before the vote the penalty is not due.
      final vote = lost.indexWhere((e) => e.type == EventTypes.seriesVote);
      expect(lost[vote + 1].type, EventTypes.penaltyPending);
      expect(
        refusal(swap(lost, vote, lost[vote + 1])..removeAt(vote + 1)),
        contains('series.vote'),
      );
    });

    test('the penalty still applies when the vote ends the game', () {
      final lost = playMatch(seed: lostSeed);
      expect(coinsFor(lost, CoinReason.lossPenalty), hasLength(1));
      expect(
        refusal([
          for (final event in lost)
            if (event.type != EventTypes.penaltyPending) event,
        ]),
        contains('should be'),
      );
    });

    test('the match played with a 2 showing ends the game with no vote', () {
      const last = SeriesRef(id: seriesTwo, match: 5, record: 4);
      final events = playMatch(seed: lostSeed, series: last);
      expect(events.map((e) => e.type), isNot(contains(EventTypes.seriesVote)));
      final outcome = complete(events);
      expect(
        (outcome.outcome, outcome.recordAfter, outcome.continues),
        (MatchOutcome.lost, 3, false),
      );
      expect(coinsFor(events, CoinReason.lossPenalty), hasLength(1));
      expect(
        refusal([
          ...events.take(events.length - 1),
          raw(
            EventTypes.seriesVote,
            Actors.user,
            SeriesPayloads.vote(continueGame: true),
          ),
        ]),
        contains('should be series.ended'),
      );
    });

    test('a game the vote ends level refunds every fee, once', () {
      const level = SeriesRef(id: seriesTwo, match: 4, record: -1);
      final tied = playMatch(seed: wonSeed, stake: 500, series: level);
      expect(coinsFor(tied, CoinReason.tieRefund), const [
        CoinEntry(CoinReason.tieRefund, 2000),
      ]);
      expect(complete(tied).recordAfter, 0);
      // Penalties are not refunded; the winnings stay.
      expect(coinsFor(tied, CoinReason.matchWon), hasLength(1));
    });

    test('no refund is due when the game is not level, or goes on', () {
      final notLevel = playMatch(seed: wonSeed);
      final end = notLevel.length - 1;
      expect(
        refusal([
          ...notLevel.take(end),
          raw(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.tieRefund(matches: 1),
          ),
          notLevel[end],
        ]),
        contains('should be'),
      );
      const level = SeriesRef(id: seriesTwo, match: 2, record: -1);
      final goesOn = playMatch(
        seed: wonSeed,
        series: level,
        continueGame: true,
      );
      expect(coinsFor(goesOn, CoinReason.tieRefund), isEmpty);
      expect(
        refusal([
          ...goesOn,
          raw(
            EventTypes.rewardPending,
            Actors.system,
            EconomyPayloads.tieRefund(matches: 2),
          ),
        ]),
        'events follow the vote to play on',
      );
    });

    test('quitting returns a share of the pot by score and ends the game', () {
      for (final actions in [10, 20, 30, 40]) {
        final quit = playMatch(
          seed: 3,
          stake: 1000,
          actions: actions,
          abandon: true,
          series: const SeriesRef(id: seriesTwo, match: 3, record: 2),
        );
        final score =
            quit
                    .firstWhere((e) => e.type == EventTypes.matchAbandoned)
                    .payload['score']!
                as int;
        final outcome = complete(quit);
        expect(
          (outcome.outcome, outcome.recordAfter, outcome.continues),
          (MatchOutcome.quit, 2, false),
          reason: 'the quit match does not count in the record',
        );
        expect(coinsFor(quit, CoinReason.quitRefund), [
          CoinEntry(
            CoinReason.quitRefund,
            CoinRules.quitRefund(1000, seats: 4, humans: 1, score: score),
          ),
        ]);
        expect(coinsFor(quit, CoinReason.lossPenalty), isEmpty);
      }
    });

    test('a quit must give the score the replay reaches', () {
      final quit = playMatch(seed: 3, actions: 40, abandon: true);
      final at = quit.indexWhere((e) => e.type == EventTypes.matchAbandoned);
      final score = quit[at].payload['score']! as int;
      final faked = [
        ...quit.take(at),
        raw(
          EventTypes.matchAbandoned,
          Actors.user,
          SeriesPayloads.abandoned(score: score + 4),
        ),
        raw(
          EventTypes.rewardPending,
          Actors.system,
          EconomyPayloads.quitRefund(score: score + 4),
        ),
        quit.last,
      ];
      expect(refusal(faked), contains('should be match.abandoned'));
    });

    test('a match that names no place in a game is refused', () {
      final created = won.first;
      expect(
        refusal(
          swap(
            won,
            0,
            raw(
              created.type,
              created.actor,
              {...created.payload}..remove('series'),
            ),
          ),
        ),
        'match.created has no valid place in a game',
      );
    });

    test(
      'the table key leaves out only the seed and the place in the game',
      () {
        final created = won.first.payload;
        final next = {
          ...created,
          'seed': seedToHex(99),
          'series': const SeriesRef(
            id: seriesOne,
            match: 2,
            record: 1,
          ).toJson(),
        };
        expect(tableKeyOf(next), tableKeyOf(created));
        expect(
          tableKeyOf({...created, 'stake': 500}),
          isNot(tableKeyOf(created)),
        );
      },
    );
  });
}
