import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat 3 deals; seat 0 holds all eight hearts and leads them. The other
/// seats hold one suit each, so seat 0 wins every trick.
Table bidderTakesAll({
  TwentyNineConfig config = testConfig,
  List<TwentyNineAction> doubling = const [
    NoDouble(Seat(1)),
    NoDouble(Seat(3)),
  ],
  int bid = 16,
}) {
  final table = Table.deal(
    config: config,
    hands: {0: 'JH 9H AH 10H KH QH 8H 7H'},
  )..auction(0, bid);
  table
    ..chooseTrump('H')
    ..actAll(config.doubleRedouble ? doubling : const [])
    ..play('JH')
    ..ask();
  while (table.state.dealNumber == 1 && !table.state.isOver) {
    table.act(table.legal().first);
  }
  return table;
}

/// Seat 0 deals; seat 2 bids with diamonds as trump. Seat 1 holds all the
/// hearts and seat 3 all the diamonds, so the bidders win nothing.
Table biddersTakeNothing({TwentyNineConfig config = testConfig}) {
  final table = Table.deal(
    dealer: 0,
    config: config,
    hands: {
      1: 'JH 9H AH 10H KH QH 8H 7H',
      3: 'JD 9D AD 10D KD QD 8D 7D',
      0: 'JS 9S AS 10S JC 9C AC 10C',
      2: 'KS QS 8S 7S KC QC 8C 7C',
    },
  )..startPlay(winner: 2, suit: 'D');
  table
    ..play('JH')
    ..ask();
  while (table.state.dealNumber == 1 && !table.state.isOver) {
    table.act(table.legal().first);
  }
  return table;
}

void main() {
  group('scoring (AGENTS.md §6.11)', () {
    test('card points plus the last trick make 29', () {
      final scored = bidderTakesAll().eventsOf<DealScored>().single;
      expect(scored.teamPoints, [29, 0]);
    });

    test('without the last-trick point they make 28', () {
      final table = bidderTakesAll(
        config: testConfig.copyWith(lastTrickPoint: false),
      );
      expect(table.eventsOf<DealScored>().single.teamPoints, [28, 0]);
    });

    test('reaching the target gains the stake', () {
      final table = bidderTakesAll();
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.outcome, DealOutcome.contractMade);
      expect(scored.team, 0);
      expect(scored.target, 16);
      expect(scored.stake, 1);
      expect(scored.delta, 1);
      expect(scored.scores, [1, 0]);
      expect(table.state.scores, [1, 0]);
      expect(scored.payload['outcome'], 'contractMade');
    });

    test('the highest bid can be made', () {
      final scored = bidderTakesAll(bid: 29).eventsOf<DealScored>().single;
      expect(scored.outcome, DealOutcome.contractMade);
    });

    test('falling short loses the stake; only the bidders\' score moves', () {
      final table = biddersTakeNothing();
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.outcome, DealOutcome.contractFailed);
      expect(scored.teamPoints, [0, 29]);
      expect(scored.team, 0);
      expect(scored.delta, -1);
      expect(table.state.scores, [-1, 0]);
    });

    test('a double makes the stake 2 and a redouble 4', () {
      final doubled = bidderTakesAll(
        doubling: const [
          Double(Seat(1)),
          NoRedouble(Seat(0)),
          NoRedouble(Seat(2)),
        ],
      );
      expect(doubled.state.scores, [2, 0]);
      final redoubled = bidderTakesAll(
        doubling: const [Double(Seat(1)), Redouble(Seat(0))],
      );
      expect(redoubled.state.scores, [4, 0]);
    });

    test('the match ends when a team reaches the target', () {
      final table = bidderTakesAll(
        config: testConfig.copyWith(targetGamePoints: 4),
        doubling: const [Double(Seat(1)), Redouble(Seat(0))],
      );
      final ended = table.eventsOf<MatchEnded>().single;
      expect(ended.winningTeam, 0);
      expect(ended.scores, [4, 0]);
      expect(ended.payload, {
        'winningTeam': 0,
        'scores': [4, 0],
      });
      final state = table.state;
      expect(state.isOver, isTrue);
      expect(state.turn, isNull);
      expect(state.winningTeam, 0);
      final result = Table.game.result(state)!;
      expect(result.winners, [const Seat(0), const Seat(2)]);
      expect(result.details['scores'], [4, 0]);
      for (final seat in [0, 1, 2, 3]) {
        expect(table.legal(seat), isEmpty);
        expect(table.view(seat).winningTeam, 0);
      }
      expect(
        () => table.act(const Pass(Seat(0))),
        throwsA(
          isA<IllegalActionException>().having(
            (e) => e.reason,
            'reason',
            'the match is over',
          ),
        ),
      );
    });

    test('or falls to minus the target, and the other team wins', () {
      final table = biddersTakeNothing(
        config: testConfig.copyWith(targetGamePoints: 1),
      );
      expect(table.state.scores, [-1, 0]);
      expect(table.eventsOf<MatchEnded>().single.winningTeam, 1);
      expect(Table.game.result(table.state)!.winners, [
        const Seat(1),
        const Seat(3),
      ]);
    });

    test('there is no result while the match is played', () {
      expect(Table.game.result(Table.deal().state), isNull);
    });
  });

  group('who won the deal (for the coin rewards, docs/decisions.md D-024)', () {
    test('the bidding team, when it makes its contract', () {
      expect(bidderTakesAll().eventsOf<DealScored>().single.winningTeam, 0);
    });

    test('the other team, when the contract fails', () {
      expect(biddersTakeNothing().eventsOf<DealScored>().single.winningTeam, 1);
    });

    DealScored scored(DealOutcome outcome, int team) => DealScored(
      outcome: outcome,
      team: team,
      delta: 0,
      stake: 3,
      teamPoints: const [15, 14],
      scores: const [0, 0],
    );

    test("a single hand: the declarer's team if it won every trick", () {
      expect(scored(DealOutcome.singleHandWon, 1).winningTeam, 1);
      expect(scored(DealOutcome.singleHandLost, 1).winningTeam, 0);
      expect(scored(DealOutcome.contractMade, 1).winningTeam, 1);
      expect(scored(DealOutcome.contractFailed, 0).winningTeam, 1);
    });

    test('nobody, when the deal is void', () {
      expect(scored(DealOutcome.voided, 0).winningTeam, isNull);
      expect(scored(DealOutcome.voided, 1).winningTeam, isNull);
    });
  });
}
