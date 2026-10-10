import 'dart:isolate';

import 'package:bots/bots.dart';
import 'package:card_games/features/games/twentynine/bot_players.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_twentynine/game_twentynine.dart';

/// An isolate that ends before it can serve anything.
void _exitAtOnce(SendPort replies) {}

/// An isolate that takes requests and never answers them.
void _neverAnswer(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((_) {});
}

void main() {
  const game = TwentyNineGame();
  final state = game.init(const TwentyNineConfig().toMatchConfig(), 7);
  final seat = state.turn!;
  final view = game.viewFor(state, seat);
  bool legal(TwentyNineAction action) =>
      game.legalActions(state, seat).contains(action);

  /// A decider whose isolates start with [entryPoint], counting the starts.
  (IsolateBotDecider, int Function()) counting({
    void Function(SendPort)? entryPoint,
    Duration limit = const Duration(seconds: 5),
  }) {
    var starts = 0;
    final decider = IsolateBotDecider(
      start: () {
        starts++;
        return entryPoint == null
            ? IsolateBotRunner.start()
            : IsolateBotRunner.start(entryPoint: entryPoint);
      },
      limit: limit,
    );
    addTearDown(decider.close);
    return (decider, () => starts);
  }

  test('a healthy isolate decides and is kept for the next decision', () async {
    final (decider, starts) = counting();
    expect(legal(await decider(view, BotLevel.skilled, 1)), isTrue);
    expect(legal(await decider(view, BotLevel.skilled, 2)), isTrue);
    expect(starts(), 1);
  });

  test('if the isolate does not start, a Beginner decides and the next '
      'decision starts a fresh isolate', () async {
    final (decider, starts) = counting(entryPoint: _exitAtOnce);
    expect(legal(await decider(view, BotLevel.skilled, 1)), isTrue);
    expect(legal(await decider(view, BotLevel.skilled, 2)), isTrue);
    expect(starts(), 2);
  });

  test('a stalled isolate is given up after the time limit', () async {
    final (decider, starts) = counting(
      entryPoint: _neverAnswer,
      limit: const Duration(milliseconds: 200),
    );
    final watch = Stopwatch()..start();
    expect(legal(await decider(view, BotLevel.skilled, 1)), isTrue);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(legal(await decider(view, BotLevel.skilled, 2)), isTrue);
    expect(starts(), 2);
  });
}
