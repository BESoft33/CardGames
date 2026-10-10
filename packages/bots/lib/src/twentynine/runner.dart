import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import '../bot.dart';
import 'twentynine_bot.dart';

/// A request to a bot as it crosses an isolate boundary (AGENTS.md §8.1):
/// the seat's view as JSON, the level, the bot's own seed and its budget.
/// Nothing else about the match is sent.
String encodeBotRequest(
  TwentyNineView view,
  BotLevel level,
  int seed, {
  int? budget,
}) => jsonEncode({
  'level': level.name,
  'seed': seedToHex(seed),
  'budget': budget ?? level.settings.searchBudget,
  'view': view.toJson(),
});

/// Answers a request made by [encodeBotRequest] with the chosen action, as
/// JSON.
String answerBotRequest(String request) {
  final json = jsonDecode(request) as Map<String, Object?>;
  final view = TwentyNineView.fromJson(json['view']! as Map<String, Object?>);
  final level = BotLevel.values.byName(json['level']! as String);
  final context = BotContext.seeded(
    seedFromHex(json['seed']! as String),
    budget: json['budget']! as int,
  );
  return jsonEncode(TwentyNineBot(level).decide(view, context).toJson());
}

TwentyNineAction _decodeAction(String json) =>
    TwentyNineAction.fromJson(jsonDecode(json) as Map<String, Object?>);

/// Runs bots in the calling isolate, still passing them only the serialised
/// view, exactly as [IsolateBotRunner] does. For tools and tests that play
/// many deals inside their own worker isolates.
final class DirectBotRunner {
  /// Creates the runner.
  const DirectBotRunner();

  /// The decision of a bot of [level] on [view], with its own [seed].
  TwentyNineAction decide(
    TwentyNineView view,
    BotLevel level,
    int seed, {
    int? budget,
  }) => _decodeAction(
    answerBotRequest(encodeBotRequest(view, level, seed, budget: budget)),
  );
}

/// Thrown when a bot fails to decide, for example because its isolate
/// stopped.
final class BotFailure implements Exception {
  /// Creates the failure.
  const BotFailure(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'BotFailure: $message';
}

/// Runs bots in their own isolate (AGENTS.md §8.1). Only the serialised view
/// goes in and only the serialised action comes out, so the match state is
/// out of the bots' reach. The isolate keeps nothing between requests.
///
/// Every failure comes back as a [BotFailure], never as a wait without end:
/// an isolate that does not start, stops, or crashes fails the decisions it
/// owes and every later one.
final class IsolateBotRunner {
  IsolateBotRunner._();

  /// Starts the bots' isolate.
  ///
  /// [entryPoint] replaces the bots' request loop; it exists so tests can
  /// start an isolate that misbehaves.
  static Future<IsolateBotRunner> start({
    void Function(SendPort replies) entryPoint = _serve,
  }) async {
    final runner = IsolateBotRunner._();
    runner._replies.listen(runner._receive);
    try {
      runner._isolate = await Isolate.spawn(
        entryPoint,
        runner._replies.sendPort,
        debugName: 'bots',
        onError: runner._replies.sendPort,
        onExit: runner._replies.sendPort,
      );
      runner._requests = await runner._ready.future;
    } on Object catch (error) {
      runner.close();
      if (error is BotFailure) rethrow;
      throw BotFailure('the bot isolate did not start: $error');
    }
    return runner;
  }

  final ReceivePort _replies = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>()..future.ignore();
  final Map<int, Completer<String>> _pending = {};
  Isolate? _isolate;
  late final SendPort _requests;
  int _nextId = 0;
  bool _closed = false;
  String? _stopped;

  void _receive(Object? message) {
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
    } else if (message is List<Object?> && message.length == 3) {
      final completer = _pending.remove(message[0]);
      if (completer == null) return;
      if (message[1] == true) {
        completer.complete(message[2]! as String);
      } else {
        completer.completeError(BotFailure('${message[2]}'));
      }
    } else {
      // The isolate failed or exited: nothing it owes will be answered.
      _stop('bot isolate stopped: $message');
    }
  }

  void _stop(String reason) {
    _stopped ??= reason;
    if (!_ready.isCompleted) _ready.completeError(BotFailure(reason));
    for (final completer in _pending.values) {
      completer.completeError(BotFailure(reason));
    }
    _pending.clear();
  }

  /// The decision of a bot of [level] on [view], with its own [seed].
  Future<TwentyNineAction> decide(
    TwentyNineView view,
    BotLevel level,
    int seed, {
    int? budget,
  }) async {
    if (_closed) throw const BotFailure('the runner is closed');
    if (_stopped case final reason?) throw BotFailure(reason);
    final id = _nextId++;
    final reply = Completer<String>();
    _pending[id] = reply;
    _requests.send([id, encodeBotRequest(view, level, seed, budget: budget)]);
    return _decodeAction(await reply.future);
  }

  /// Stops the isolate. Pending decisions fail.
  void close() {
    if (_closed) return;
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _replies.close();
    _stop('the runner was closed');
  }
}

void _serve(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((message) {
    final [id, request] = message! as List<Object?>;
    try {
      replies.send([id, true, answerBotRequest(request! as String)]);
    } catch (error) {
      replies.send([id, false, '$error']);
    }
  });
}

/// The pause before a bot's action is shown: 0.6 to 1.8 seconds
/// (AGENTS.md §8.4). Purely for the look of play; the decision never waits.
Duration cosmeticDelay(Xoshiro256StarStar random) =>
    Duration(milliseconds: 600 + random.nextBounded(1201));
