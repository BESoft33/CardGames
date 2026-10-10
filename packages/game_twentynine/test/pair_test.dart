import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat 3 deals; seat 0 leads and bids. Seat 1 holds KH QH, seat 2 KS QS.
const Map<int, String> handsPair = {
  0: 'JS 9S JH 9H 7D 8D 7C 8C',
  1: 'KH QH AS 10S 9D 10D AC 10C',
  2: 'KS QS 8S 7S JD AD KD QD',
  3: 'AH 10H 8H 7H JC 9C KC QC',
};

/// Hearts are trump. Seat 3 wins the hidden-trump first trick, then the
/// trick in which seat 2 asks; seat 1 holds the Pair.
Table opponentsPair({int bid = 16, TwentyNineConfig config = testConfig}) {
  final table = Table.deal(hands: handsPair, config: config)
    ..startPlay(bid: bid, suit: 'H')
    ..play('7C 10C 7S JC');
  expect(table.state.phase, TwentyNinePhase.play, reason: 'trump hidden');
  expect(table.turn, const Seat(3));
  table
    ..play('9C 8C AC')
    ..ask()
    ..play('8S');
  return table;
}

/// Spades are trump. Seat 2 asks, trumps with 7S and wins: its own Pair.
Table biddersPair(int bid) {
  final table = Table.deal(hands: handsPair)
    ..startPlay(bid: bid, suit: 'S')
    ..play('7C 10C')
    ..ask()
    ..play('7S JC');
  return table;
}

void main() {
  group('the Pair (AGENTS.md §6.10)', () {
    test('is offered after a trick won once trump is revealed', () {
      final table = opponentsPair();
      expect(table.eventsOf<TrickWon>().last.winner, const Seat(3));
      expect(table.state.phase, TwentyNinePhase.pair);
      expect(table.turn, const Seat(1));
      expect(table.legal(), const [DeclarePair(Seat(1)), NoPair(Seat(1))]);
    });

    test('the offer is visible only to its holder', () {
      final table = opponentsPair();
      expect(table.view(1).phase, TwentyNinePhase.pair);
      expect(table.view(1).turn, const Seat(1));
      for (final seat in [0, 2, 3]) {
        final view = table.view(seat);
        expect(view.phase, TwentyNinePhase.play);
        expect(view.turn, isNull);
        expect(view.legalActions, isEmpty);
      }
    });

    test('the trick in which trump is revealed counts', () {
      final table = Table.deal(hands: handsPair)
        ..startPlay(suit: 'H')
        ..play('7C 10C')
        ..ask()
        ..play('7S JC');
      expect(table.state.revealTrick, 0);
      expect(table.state.phase, TwentyNinePhase.pair);
      expect(table.turn, const Seat(1));
    });

    test('declared by the opponents, it raises the target by 4', () {
      final table = opponentsPair()..act(const DeclarePair(Seat(1)));
      expect(table.state.target, 20);
      expect(table.state.contract, 16);
      expect(table.state.pairBy, const Seat(1));
      expect(table.eventsOf<TargetChanged>().single.target, 20);
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.turn, const Seat(3), reason: 'the trick winner leads');
      for (final seat in [0, 1, 2, 3]) {
        expect(table.view(seat).pairBy, const Seat(1));
        expect(table.view(seat).target, 20);
      }
    });

    test('but not above the highest bid', () {
      final table = opponentsPair(bid: 27)..act(const DeclarePair(Seat(1)));
      expect(table.state.target, 29);
    });

    test('declared by the bidding team, it lowers the target by 4', () {
      final table = biddersPair(24);
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(2));
      expect(table.turn, const Seat(2));
      table.act(const DeclarePair(Seat(2)));
      expect(table.state.target, 20);
    });

    test('but not below the minimum bid', () {
      final table = biddersPair(18)..act(const DeclarePair(Seat(2)));
      expect(table.state.target, 16);
    });

    test('at most one Pair per deal', () {
      final table = opponentsPair()
        ..act(const DeclarePair(Seat(1)))
        ..play('KC 7D 9D QD');
      expect(table.eventsOf<TrickWon>().last.winner, const Seat(3));
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.turn, const Seat(3));
    });

    test('declining keeps the chance for a later trick', () {
      final table = opponentsPair()
        ..act(const NoPair(Seat(1)))
        ..play('KC 7D 9D QD');
      expect(table.eventsOf<ActionTaken>().last.name, 'cardPlayed');
      expect(table.state.phase, TwentyNinePhase.pair);
      expect(table.turn, const Seat(1));
    });

    test('is not offered once the holder has played one of the two', () {
      final table = Table.deal(hands: handsPair)
        ..startPlay(suit: 'H')
        ..play('7C 10C')
        ..ask()
        ..play('7S JC')
        ..act(const NoPair(Seat(1)))
        // Seat 1 must follow hearts with QH; seat 0 wins with JH.
        ..play('7H JH QH 8S')
        // Seat 3 trumps the diamond lead and wins.
        ..play('8D 10D QD 8H');
      expect(table.eventsOf<TrickWon>().last.winner, const Seat(3));
      expect(table.state.phase, TwentyNinePhase.play);
    });

    test('is not offered when the option is off', () {
      final table = opponentsPair(config: testConfig.copyWith(pair: false));
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.turn, const Seat(3));
    });

    test('the deal is scored against the moved target', () {
      final table = opponentsPair()..act(const DeclarePair(Seat(1)));
      while (table.state.dealNumber == 1) {
        table.act(table.legal().firstWhere((a) => a is PlayCard));
      }
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.target, 20);
      expect(
        scored.outcome,
        scored.teamPoints[0] >= 20
            ? DealOutcome.contractMade
            : DealOutcome.contractFailed,
      );
    });
  });
}
