import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'golden/replays.dart';

/// Golden replays (AGENTS.md §14): complete matches recorded with this rules
/// version must replay to exactly the same states and events.
void main() {
  const game = TwentyNineGame();
  final replays = (jsonDecode(goldenReplaysJson) as List<Object?>)
      .cast<Map<String, Object?>>();

  test('there are recorded replays for this rules version', () {
    expect(replays, isNotEmpty);
    for (final replay in replays) {
      expect(replay['rulesVersion'], game.rulesVersion);
    }
  });

  for (final replay in replays) {
    test('replays "${replay['name']}" exactly', () {
      final rules = replay['rules']! as Map<String, Object?>;
      var state = game.init(
        MatchConfig(rules: rules),
        seedFromHex(replay['seed']! as String),
      );
      final events = [...state.lastEvents];
      for (final json in replay['actions']! as List<Object?>) {
        final action = TwentyNineAction.fromJson(json! as Map<String, Object?>);
        state = game.apply(state, action);
        events.addAll(state.lastEvents);
      }
      expect(state.isOver, isTrue);
      // The events alone are enough to replay the match (AGENTS.md §9).
      final logged = [
        for (final event in events)
          if (event.actor case final actor?)
            ?TwentyNineAction.fromEvent(event.type, actor.id, event.payload),
      ];
      expect([for (final action in logged) action.toJson()], replay['actions']);
      expect(state.dealNumber, replay['deals']);
      expect(state.scores, replay['scores']);
      expect(state.winningTeam, replay['winningTeam']);
      expect(state.hash, replay['finalStateHash']);
      expect(
        canonicalHash([for (final event in events) event.toJson()]),
        replay['eventsHash'],
      );
    });
  }
}
