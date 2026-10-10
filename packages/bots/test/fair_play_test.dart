import 'dart:convert';

import 'package:bots/bots.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The fair-play tests required by AGENTS.md §8.1: a bot's decision depends
/// on nothing but its seat's view, its own seed and its budget.
void main() {
  const runner = DirectBotRunner();

  /// Every level's decision on [a] and on [b], seat [seat], with [seed].
  void expectSameDecisions(
    TwentyNineState a,
    TwentyNineState b,
    Seat seat,
    int seed,
    String why,
  ) {
    final viewA = game.viewFor(a, seat);
    final viewB = game.viewFor(b, seat);
    expect(
      canonicalJson(viewB.toJson()),
      canonicalJson(viewA.toJson()),
      reason: 'the views must match: $why',
    );
    expect(b.hash, isNot(a.hash), reason: 'the states must differ: $why');
    for (final level in BotLevel.values) {
      expect(
        runner.decide(viewB, level, seed),
        runner.decide(viewA, level, seed),
        reason: '${level.name}: $why',
      );
    }
  }

  test(
    'view equivalence: different states with equal views, same decision',
    () {
      final random = Xoshiro256StarStar.seeded(81);
      var checked = 0;
      while (checked < 150) {
        final position = randomPosition(random);
        final deck = swapHiddenCards(position, random, swaps: 3);
        if (deck == null) continue;
        // Another deck, and another match seed as well.
        final other = position.replay(deck, position.seed ^ 0x9E3779B9);
        expectSameDecisions(
          position.state,
          other,
          position.seat,
          random.nextInt64(),
          'position $checked',
        );
        checked++;
      }
    },
  );

  test(
    'hidden shuffle: unseen cards moved between other seats, same decision',
    () {
      final random = Xoshiro256StarStar.seeded(82);
      var checked = 0;
      while (checked < 150) {
        final position = randomPosition(random);
        final deck = swapHiddenCards(position, random);
        if (deck == null) continue;
        final other = position.replay(deck, position.seed);
        expectSameDecisions(
          position.state,
          other,
          position.seat,
          random.nextInt64(),
          'position $checked',
        );
        checked++;
      }
    },
  );

  test('serialisation: a non-bidder\'s request before the reveal holds no '
      'trump suit and no card from another hand', () {
    final random = Xoshiro256StarStar.seeded(83);
    var checked = 0;
    while (checked < 300) {
      final state = randomPosition(random).state;
      final bidder = state.bidder;
      if (bidder == null || state.trumpRevealed) continue;
      for (var index = 0; index < 4; index++) {
        final seat = Seat(index);
        if (seat == bidder) continue;
        final view = game.viewFor(state, seat);
        final request = encodeBotRequest(view, BotLevel.skilled, 1);
        final sent = jsonDecode(request) as Map<String, Object?>;
        final trump = (sent['view']! as Map)['trump']! as Map;
        expect(trump['suit'], isNull, reason: request);
        expect(trump['seventhCard'], isNull, reason: request);
        final visible = visibleCards(state, seat);
        for (final card in TwentyNineRules.deck) {
          if (visible.contains(card)) continue;
          expect(
            request.contains('"${card.id}"'),
            isFalse,
            reason: '${card.id} must not reach ${seat.id}',
          );
        }
        checked++;
      }
    }
  });

  test('bots in their own isolate decide exactly as in-process bots', () async {
    final isolated = await IsolateBotRunner.start();
    addTearDown(isolated.close);
    final random = Xoshiro256StarStar.seeded(84);
    for (var i = 0; i < 60; i++) {
      final position = randomPosition(random);
      final view = game.viewFor(position.state, position.seat);
      final seed = random.nextInt64();
      for (final level in BotLevel.values) {
        expect(
          await isolated.decide(view, level, seed),
          runner.decide(view, level, seed),
        );
      }
    }
  });
}
