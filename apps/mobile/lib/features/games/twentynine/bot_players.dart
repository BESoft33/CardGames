import 'package:bots/bots.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

/// Asks a bot of [level] for its decision on [view], with its own [seed].
typedef BotDecider = Future<TwentyNineAction> Function(
  TwentyNineView view,
  BotLevel level,
  int seed,
);

/// Bots deciding in their own isolate, for the table.
final botDeciderProvider = Provider<BotDecider>((ref) {
  final decider = IsolateBotDecider();
  ref.onDispose(decider.close);
  return decider.call;
});

/// Asks bots for decisions in their own isolate (AGENTS.md §8.1).
///
/// If the isolate does not start, stops, or takes longer than [limit], that
/// one decision falls to a Beginner bot in-process, which still sees only
/// the serialised view, so play goes on. The next decision starts a fresh
/// isolate. Search budgets keep real decisions far below [limit]; the limit
/// is the wall-clock safety net of AGENTS.md §8.4.
final class IsolateBotDecider {
  /// Creates a decider that starts its isolate with [start].
  IsolateBotDecider({
    this.start = IsolateBotRunner.start,
    this.limit = const Duration(seconds: 5),
  });

  /// Starts the bots' isolate.
  final Future<IsolateBotRunner> Function() start;

  /// The longest one decision may take.
  final Duration limit;

  Future<IsolateBotRunner>? _runner;

  /// The decision of a bot of [level] on [view], with its own [seed].
  Future<TwentyNineAction> call(
    TwentyNineView view,
    BotLevel level,
    int seed,
  ) async {
    final runner = _runner ??= start();
    try {
      final started = await runner;
      return await started.decide(view, level, seed).timeout(limit);
    } on Exception {
      if (identical(_runner, runner)) _runner = null;
      _stop(runner);
      return const DirectBotRunner().decide(view, BotLevel.beginner, seed);
    }
  }

  /// Stops the isolate.
  void close() {
    _stop(_runner);
    _runner = null;
  }

  static void _stop(Future<IsolateBotRunner>? runner) => runner
      ?.then<void>((started) => started.close(), onError: (Object _) {})
      .ignore();
}

/// Waits before a bot's move is shown: 0.6 to 1.8 seconds (AGENTS.md §8.4).
final botDelayProvider = Provider<Future<void> Function()>((ref) {
  final random = Xoshiro256StarStar.seeded(secureSeed());
  return () => Future<void>.delayed(cosmeticDelay(random));
});

/// How long a finished trick stays on the table before the next lead.
final trickPauseProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 900),
);

/// How long the last trick of a deal is shown going to its winner before
/// the deal's result appears: the length of that animation (1.3 seconds,
/// TrickArea), and a little more.
final dealEndPauseProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1400),
);
