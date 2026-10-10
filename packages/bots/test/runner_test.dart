import 'dart:convert';
import 'dart:isolate';

import 'package:bots/bots.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// An isolate that ends before it can serve anything.
void _exitAtOnce(SendPort replies) {}

/// An isolate that crashes as it starts.
void _crashAtOnce(SendPort replies) => throw StateError('crashed');

/// An isolate that takes one request and ends without answering it.
void _stopOnFirstRequest(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((_) => requests.close());
}

void main() {
  test('a request carries only the level, seed, budget and view', () {
    final state = dealHands(const {});
    final view = game.viewFor(state, state.turn!);
    final request =
        jsonDecode(encodeBotRequest(view, BotLevel.casual, 42)) as Map;
    expect(request.keys, unorderedEquals(['level', 'seed', 'budget', 'view']));
    expect(request['level'], 'casual');
    expect(request['seed'], seedToHex(42));
    expect(request['budget'], BotLevel.casual.settings.searchBudget);
    expect(request['view'], view.toJson());
  });

  test('the isolate runner reports a failed decision', () async {
    final runner = await IsolateBotRunner.start();
    addTearDown(runner.close);
    final state = dealHands(const {});
    // Seat 2 is not on turn, so it has nothing to decide.
    final view = game.viewFor(state, const Seat(2));
    expect(
      runner.decide(view, BotLevel.beginner, 1),
      throwsA(isA<BotFailure>()),
    );
    // The isolate keeps serving after a failure.
    final good = game.viewFor(state, state.turn!);
    expect(
      await runner.decide(good, BotLevel.beginner, 1),
      isA<TwentyNineAction>(),
    );
  });

  test('a closed runner refuses work', () async {
    final runner = await IsolateBotRunner.start();
    runner.close();
    final state = dealHands(const {});
    expect(
      () => runner.decide(game.viewFor(state, state.turn!), BotLevel.casual, 1),
      throwsA(isA<BotFailure>()),
    );
    runner.close();
  });

  group('a failing isolate gives a BotFailure, never a wait without end', () {
    test('when it ends before serving', () {
      expect(
        IsolateBotRunner.start(entryPoint: _exitAtOnce),
        throwsA(isA<BotFailure>()),
      );
    });

    test('when it crashes as it starts', () {
      expect(
        IsolateBotRunner.start(entryPoint: _crashAtOnce),
        throwsA(isA<BotFailure>()),
      );
    });

    test('when it stops while a decision is pending, and after', () async {
      final runner = await IsolateBotRunner.start(
        entryPoint: _stopOnFirstRequest,
      );
      addTearDown(runner.close);
      final state = dealHands(const {});
      final view = game.viewFor(state, state.turn!);
      await expectLater(
        runner.decide(view, BotLevel.casual, 1),
        throwsA(isA<BotFailure>()),
      );
      await expectLater(
        runner.decide(view, BotLevel.casual, 2),
        throwsA(isA<BotFailure>()),
      );
    });
  });

  test('the cosmetic delay is 0.6 to 1.8 seconds', () {
    final random = Xoshiro256StarStar.seeded(3);
    final delays = [for (var i = 0; i < 2000; i++) cosmeticDelay(random)];
    for (final delay in delays) {
      expect(delay.inMilliseconds, inInclusiveRange(600, 1800));
    }
    expect(
      delays.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b),
      lessThan(700),
    );
    expect(
      delays.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b),
      greaterThan(1700),
    );
  });
}
