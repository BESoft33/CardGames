import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'leaks.dart';

const TwentyNineGame game = TwentyNineGame();

/// Rule options drawn at random, with the match target mostly at 6.
TwentyNineConfig randomConfig(Xoshiro256StarStar rng) {
  bool coin() => rng.nextBounded(2) == 0;
  T pick<T>(List<T> values) => values[rng.nextBounded(values.length)];
  return TwentyNineConfig(
    direction: pick(PlayDirection.values),
    minBid: pick(TwentyNineConfig.allowedMinBids),
    lastTrickPoint: coin(),
    askTrump: pick(AskTrumpRule.values),
    allPass: pick(AllPassRule.values),
    pair: coin(),
    doubleRedouble: coin(),
    seventhCard: coin(),
    redealChecks: coin(),
    singleHand: coin(),
    targetGamePoints: pick([1, 3, 6, 6, 6, 10]),
  );
}

/// Every card exactly once across hands, table, tricks and the undealt
/// cards (AGENTS.md §6.12).
String? cardsProblem(TwentyNineState s) {
  final all = <Card>[
    for (final hand in s.hands) ...hand,
    ...s.undealt,
    for (final trick in s.tricks)
      for (final play in trick.plays) play.card,
    for (final play in s.trick) play.card,
    if (s.seventhCardSetAside) s.seventhCard!,
  ];
  if (all.length != 32 || all.toSet().length != 32) {
    return '${all.length} cards, ${all.toSet().length} distinct';
  }
  final won = s.tricks.fold(0, (sum, t) => sum + t.points);
  if (s.cardPoints[0] + s.cardPoints[1] != won) {
    return 'card points ${s.cardPoints} do not add up to $won';
  }
  return null;
}

/// The checks on a scored deal (AGENTS.md §6.11 and §6.12).
String? dealProblem(DealScored scored, TwentyNineConfig config) {
  final total = scored.teamPoints[0] + scored.teamPoints[1];
  switch (scored.outcome) {
    case DealOutcome.contractMade ||
        DealOutcome.contractFailed ||
        DealOutcome.voided:
      if (total != (config.lastTrickPoint ? 29 : 28)) {
        return 'points total $total';
      }
      final made = scored.teamPoints[scored.team] >= scored.target!;
      final expected = switch (scored.outcome) {
        DealOutcome.voided => 0,
        _ => made ? scored.stake : -scored.stake,
      };
      if (scored.delta != expected) return 'delta ${scored.delta}';
      if (scored.outcome == DealOutcome.contractMade && !made) {
        return 'made without reaching the target';
      }
    case DealOutcome.singleHandWon || DealOutcome.singleHandLost:
      if (scored.stake != 3 || scored.delta.abs() != 3) {
        return 'single hand scored ${scored.delta}';
      }
  }
  return null;
}

void main() {
  test('10,000 random legal matches keep every invariant', () {
    final rng = Xoshiro256StarStar.seeded(29);
    final seen = <String, int>{};
    void count(String what) =>
        seen.update(what, (n) => n + 1, ifAbsent: () => 1);

    for (var match = 0; match < 10000; match++) {
      final config = randomConfig(rng);
      final seed = rng.nextInt64();
      final actions = <TwentyNineAction>[];
      var state = game.init(config.toMatchConfig(), seed);
      String where() =>
          'match $match, seed ${seedToHex(seed)}, '
          'action ${actions.length}, $config';

      while (!state.isOver) {
        final problem = cardsProblem(state);
        if (problem != null) fail('$problem at ${where()}');
        final turn = state.turn!;
        final legal = game.legalActions(state, turn);
        if (legal.isEmpty) fail('no legal action at ${where()}');
        for (var i = 1; i < 4; i++) {
          final other = turn.offset(i, 4);
          if (game.legalActions(state, other).isNotEmpty) {
            fail('${other.id} may act out of turn at ${where()}');
          }
        }

        if (rng.nextBounded(8) == 0) {
          // Anything outside the legal list is refused.
          final card = TwentyNineRules.deck[rng.nextBounded(32)];
          final probes = <TwentyNineAction>[
            Pass(turn.offset(1 + rng.nextBounded(3), 4)),
            PlayCard(turn, card),
            Bid(turn, 30),
          ];
          for (final probe in probes) {
            if (legal.contains(probe)) continue;
            try {
              game.apply(state, probe);
              fail('$probe was accepted at ${where()}');
            } on IllegalActionException {
              // Expected.
            }
          }
        }
        if (rng.nextBounded(16) == 0) {
          for (var seat = 0; seat < 4; seat++) {
            final leak = leakIn(state, Seat(seat));
            if (leak != null) fail('$leak at ${where()}');
          }
        }

        final action = randomAction(legal, rng);
        state = game.apply(state, action);
        actions.add(action);
        count(action.type);
        for (final event in state.lastEvents) {
          canonicalJson(event.toJson()); // Every event is valid JSON.
          if (event is DealScored) {
            count(event.outcome.name);
            final problem = dealProblem(event, config);
            if (problem != null) fail('$problem at ${where()}');
          } else if (event is DealCancelled) {
            count(event.reason.name);
          }
        }
        if (actions.length > 20000) fail('match never ended: ${where()}');
      }

      final target = config.targetGamePoints;
      final winner = state.winningTeam!;
      if (!(state.scores[winner] >= target ||
          state.scores[1 - winner] <= -target)) {
        fail('ended at ${state.scores} with target $target: ${where()}');
      }

      // Replaying the seed and the actions gives the same state hash.
      var replay = game.init(config.toMatchConfig(), seed);
      for (final action in actions) {
        replay = game.apply(replay, action);
      }
      if (replay.hash != state.hash) fail('replay differs: ${where()}');
    }

    // Every kind of decision and ending happened at least once.
    expect(
      seen.keys,
      containsAll(<String>[
        for (final type in [
          'bid',
          'pass',
          'chooseTrump',
          'callSeventhCard',
          'double',
          'noDouble',
          'redouble',
          'noRedouble',
          'declareSingleHand',
          'noSingleHand',
          'playCard',
          'askTrump',
          'declarePair',
          'noPair',
        ])
          type,
        for (final outcome in DealOutcome.values) outcome.name,
        // Eight cards of one suit is about one deal in a million; the
        // scenario tests cover it.
        for (final reason in DealCancelReason.values)
          if (reason != DealCancelReason.eightOfOneSuit) reason.name,
      ]),
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
