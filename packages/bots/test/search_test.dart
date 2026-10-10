import 'package:bots/src/twentynine/cards.dart';
import 'package:bots/src/twentynine/knowledge.dart';
import 'package:bots/src/twentynine/search.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Rules without the Pair, which moves the target and which the solver
/// leaves out, and without redeals.
const TwentyNineConfig noPair = TwentyNineConfig(
  redealChecks: false,
  pair: false,
);

/// The cards as they really lie in [state].
World trueWorld(TwentyNineState state) => World(
  [for (final hand in state.hands) C29.maskOf(hand)],
  state.seventhCardSetAside ? C29.index(state.seventhCard!) : -1,
  state.trumpSuit?.index ?? -1,
);

/// A position in the play of the first deal with at least [tricks] tricks
/// done, reached by random legal actions.
TwentyNineState playPosition(
  Xoshiro256StarStar random, {
  int tricks = 0,
  TwentyNineConfig config = noPair,
}) {
  for (;;) {
    var state = game.init(config.toMatchConfig(), random.nextInt64());
    final stop = tricks + random.nextBounded(8 - tricks);
    var extra = random.nextBounded(4);
    for (;;) {
      final legal = game.legalActions(state, state.turn!);
      if (state.phase == TwentyNinePhase.play &&
          state.tricks.length >= stop &&
          legal.length > 1 &&
          extra-- <= 0) {
        return state;
      }
      final next = game.apply(state, legal[random.nextBounded(legal.length)]);
      if (next.dealNumber != state.dealNumber || next.isOver) break;
      state = next;
    }
  }
}

/// The bidding side's value of the deal from [state] on, every seat
/// playing its best with every card known: the engine's own rules.
int bruteForce(TwentyNineState state, int side) {
  for (final event in state.lastEvents) {
    if (event is DealScored) {
      final points = event.teamPoints[side];
      return switch (event.outcome) {
        DealOutcome.singleHandWon =>
          event.team == side ? DealValue.made : -DealValue.made,
        DealOutcome.singleHandLost =>
          event.team == side ? -DealValue.made : DealValue.made,
        DealOutcome.voided => points - 14,
        DealOutcome.contractMade => DealValue.made + points - 14,
        DealOutcome.contractFailed => -DealValue.made + points - 14,
      };
    }
  }
  final seat = state.turn!;
  final maximise = TwentyNineRules.teamOf(seat) == side;
  var best = maximise ? -100000 : 100000;
  for (final action in game.legalActions(state, seat)) {
    final value = bruteForce(game.apply(state, action), side);
    best = maximise
        ? (value > best ? value : best)
        : (value < best ? value : best);
  }
  return best;
}

void main() {
  test('the solver offers exactly the engine\'s legal actions', () {
    final random = Xoshiro256StarStar.seeded(291);
    for (var i = 0; i < 400; i++) {
      final config = i.isEven
          ? noPair
          : const TwentyNineConfig(
              redealChecks: false,
              askTrump: AskTrumpRule.mandatory,
            );
      final state = playPosition(random, config: config);
      final seat = state.turn!;
      final view = game.viewFor(state, seat);
      final world = trueWorld(state);
      final moves = Solver(DealRules.of(view, world.trump))
          .moves(DealPosition.of(view, world));
      final legal = game.legalActions(state, seat).toSet();
      final plain = {
        for (final move in moves)
          if (move & askFlag == 0) PlayCard(seat, C29.card(move)),
      };
      final asks = {
        for (final move in moves)
          if (move & askFlag != 0) C29.card(move & 31),
      };
      expect(
        {...plain, if (asks.isNotEmpty) AskTrump(seat)},
        legal,
        reason: 'position $i',
      );
      if (asks.isNotEmpty) {
        final after = game.apply(state, AskTrump(seat));
        expect(asks, {
          for (final action in game.legalActions(after, seat))
            (action as PlayCard).card,
        }, reason: 'after asking, position $i');
      }
    }
  });

  test('with every card known, the solver agrees with a search of the '
      'engine itself', () {
    final random = Xoshiro256StarStar.seeded(292);
    for (var i = 0; i < 60; i++) {
      final state = playPosition(random, tricks: 6);
      final seat = state.turn!;
      final view = game.viewFor(state, seat);
      final world = trueWorld(state);
      final rules = DealRules.of(view, world.trump);
      final solved = Solver(rules).solve(DealPosition.of(view, world));
      final maximise = TwentyNineRules.teamOf(seat) == rules.side;
      for (final action in game.legalActions(state, seat)) {
        final expected = bruteForce(game.apply(state, action), rules.side);
        final values = [
          for (final (move, value) in solved)
            if (action is PlayCard
                ? move == C29.index(action.card)
                : move & askFlag != 0)
              value,
        ];
        final got = action is PlayCard
            ? values.single
            : values.reduce(
                (a, b) => maximise ? (a > b ? a : b) : (a < b ? a : b),
              );
        expect(got, expected, reason: 'position $i, $action');
      }
    }
  });

  test('values put the outcome first and points second', () {
    expect(DealValue.outcome(DealValue.made + 15), 1);
    expect(DealValue.outcome(DealValue.made - 14), 1);
    expect(DealValue.outcome(15), 0);
    expect(DealValue.outcome(-14), 0);
    expect(DealValue.outcome(-DealValue.made + 15), -1);
    expect(DealValue.points(DealValue.made + 3), 3);
    expect(DealValue.points(-DealValue.made - 2), -2);
  });
}
