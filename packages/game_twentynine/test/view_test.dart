import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'leaks.dart';

/// Plays a seeded match with random legal actions, calling [check] on every
/// state.
void playRandomMatch(
  int seed,
  void Function(TwentyNineState state) check, {
  TwentyNineConfig config = const TwentyNineConfig(),
}) {
  const game = TwentyNineGame();
  final rng = Xoshiro256StarStar.seeded(seed);
  var state = game.init(config.toMatchConfig(), seed);
  check(state);
  while (!state.isOver) {
    final legal = game.legalActions(state, state.turn!);
    state = game.apply(state, randomAction(legal, rng));
    check(state);
  }
}

void main() {
  group('player views (AGENTS.md §8.1)', () {
    test('show the viewer\'s hand and the public facts', () {
      final table = Table.deal(hands: {0: 'JS 9S AS 10S JH 9H 7D 8D'})
        ..startPlay(suit: 'H');
      final view = table.view(0);
      expect(view.seat, const Seat(0));
      expect(view.hand, cards('JS 9S AS 10S JH 9H 7D 8D'));
      expect(view.handSizes, [8, 8, 8, 8]);
      expect(view.dealer, const Seat(3));
      expect(view.firstPlayer, const Seat(0));
      expect(view.dealNumber, 1);
      expect(view.bidder, const Seat(0));
      expect(view.contract, 16);
      expect(view.target, 16);
      expect(view.scores, [0, 0]);
      expect(view.calls, hasLength(4));
      expect(view.highBid, 16);
      expect(view.highBidder, const Seat(0));
      expect(view.config, testConfig);
      expect(view.phase, TwentyNinePhase.play);
      expect(view.turn, const Seat(0));
      expect(view.isMyTurn, isTrue);
      expect(table.view(1).isMyTurn, isFalse);
    });

    test('carry exactly the engine\'s legal actions', () {
      final table = Table.deal()..startPlay();
      for (final seat in [0, 1, 2, 3]) {
        expect(table.view(seat).legalActions, table.legal(seat));
      }
    });

    test('never show another hand, undealt cards, a seed or hidden trump', () {
      for (var seed = 0; seed < 60; seed++) {
        playRandomMatch(seed, (state) {
          for (var seat = 0; seat < 4; seat++) {
            final leak = leakIn(state, Seat(seat));
            expect(leak, isNull, reason: 'seed $seed: $leak');
          }
        });
      }
    });

    test('a non-bidder\'s view before the reveal has no trump suit', () {
      final table = Table.deal()
        ..startPlay(suit: 'S')
        ..play('JS');
      for (final seat in [1, 2, 3]) {
        final trump = table.view(seat).toJson()['trump']! as Map;
        expect(trump['suit'], isNull);
        expect(trump['revealed'], isFalse);
      }
      expect((table.view(0).toJson()['trump']! as Map)['suit'], 'S');
    });

    test('round-trip through JSON in every phase', () {
      final phases = <TwentyNinePhase>{};
      void roundTrip(TwentyNineState state) {
        phases.add(state.phase);
        for (var seat = 0; seat < 4; seat++) {
          final view = Table.game.viewFor(state, Seat(seat));
          final copy = TwentyNineView.fromJson(view.toJson());
          expect(canonicalJson(copy.toJson()), canonicalJson(view.toJson()));
          expect(copy.legalActions, view.legalActions);
        }
      }

      // A pending Pair offer: seat 1 holds KH QH and its partner wins.
      final pair =
          Table.deal(
              hands: {
                0: 'JS 9S JH 9H 7D 8D 7C 8C',
                1: 'KH QH AS 10S 9D 10D AC 10C',
                2: 'KS QS 8S 7S JD AD KD QD',
                3: 'AH 10H 8H 7H JC 9C KC QC',
              },
            )
            ..startPlay(suit: 'H')
            ..play('7C 10C')
            ..ask()
            ..play('7S JC');
      expect(pair.state.phase, TwentyNinePhase.pair);
      roundTrip(pair.state);
      for (var seed = 0; seed < 40; seed++) {
        playRandomMatch(
          seed,
          roundTrip,
          config: const TwentyNineConfig(singleHand: true),
        );
      }
      expect(phases, containsAll(TwentyNinePhase.values));
    });
  });
}
