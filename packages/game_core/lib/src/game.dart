import 'cards.dart';
import 'seat.dart';

/// The options a match starts with.
///
/// [rules] holds the game's rule options as JSON, so every game reads its own
/// keys and the options can be logged, stored and checked on the server.
final class MatchConfig {
  /// Creates a config with the given rule options.
  const MatchConfig({this.rules = const {}});

  /// The game's rule options, as JSON.
  final Map<String, Object?> rules;
}

/// How a finished match ended.
final class MatchResult {
  /// Creates a result.
  const MatchResult({required this.winners, this.details = const {}});

  /// The seats on the winning side.
  final List<Seat> winners;

  /// Game-specific details, such as final scores, as JSON.
  final Map<String, Object?> details;
}

/// Thrown by [GameDefinition.apply] for an action that is not legal.
final class IllegalActionException implements Exception {
  /// Creates the exception for [action], explaining why in [reason].
  const IllegalActionException(this.action, this.reason);

  /// The rejected action.
  final Object? action;

  /// Why the action was rejected.
  final String reason;

  @override
  String toString() => 'IllegalActionException: $reason ($action)';
}

/// A decision taken by the player in [seat]. Every game's actions implement
/// this, so they can be logged and sent over the network.
abstract interface class GameAction {
  /// The seat that takes the action.
  Seat get seat;

  /// The action as JSON.
  Map<String, Object?> toJson();
}

/// Everything the player in [seat] may see of a match, and nothing more
/// (AGENTS.md §5.5 and §8.1). The UI for a seat and every bot get only this.
abstract interface class PlayerView {
  /// The seat this view belongs to.
  Seat get seat;

  /// The view as JSON, for example to cross an isolate boundary.
  Map<String, Object?> toJson();
}

/// Something that happened in a match, as written to the event log
/// (AGENTS.md §9).
abstract interface class GameEvent {
  /// The event type, for example `twentynine.cardPlayed`.
  String get type;

  /// The seat whose action caused the event, or null for events the rules
  /// produce on their own, such as a trick being won.
  Seat? get actor;

  /// The event's data as JSON.
  Map<String, Object?> get payload;
}

/// The rules of one game, as a deterministic reducer (AGENTS.md §5).
///
/// The same seed and the same actions always give the same state, on the
/// device and on the server. Implementations use no clocks, no I/O and no
/// global randomness.
abstract interface class GameDefinition<
  S,
  A extends GameAction,
  V extends PlayerView
> {
  /// The game's ID, for example `twentynine`.
  String get id;

  /// The version of the rules. A released version never changes behaviour.
  int get rulesVersion;

  /// Every card the game is played with. The app checks that each one has
  /// card art (AGENTS.md §13).
  List<Card> get deck;

  /// Starts a match with [config], shuffling from [seed].
  S init(MatchConfig config, int seed);

  /// The actions [seat] may take now. Empty when it is not that seat's turn.
  List<A> legalActions(S state, Seat seat);

  /// Applies [action] and returns the new state.
  ///
  /// Throws an [IllegalActionException] if [action] is not one of
  /// [legalActions] for its seat.
  S apply(S state, A action);

  /// Everything [seat] may see, and nothing more.
  V viewFor(S state, Seat seat);

  /// How the match ended, or null while it is still being played.
  MatchResult? result(S state);
}

/// The games the app offers, by ID (AGENTS.md §5.4).
final class GameRegistry {
  /// Registers [games]. Throws an [ArgumentError] if two share an ID.
  GameRegistry(Iterable<GameDefinition<Object?, GameAction, PlayerView>> games)
    : _byId = {} {
    for (final game in games) {
      if (_byId.containsKey(game.id)) {
        throw ArgumentError.value(game.id, 'games', 'Duplicate game ID');
      }
      _byId[game.id] = game;
    }
  }

  final Map<String, GameDefinition<Object?, GameAction, PlayerView>> _byId;

  /// Every registered game, in registration order.
  Iterable<GameDefinition<Object?, GameAction, PlayerView>> get games =>
      _byId.values;

  /// The game with [id]. Throws an [ArgumentError] if there is none.
  GameDefinition<Object?, GameAction, PlayerView> operator [](String id) =>
      _byId[id] ?? (throw ArgumentError.value(id, 'id', 'No such game'));
}
