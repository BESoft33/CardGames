import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import '../l10n/app_localizations.dart';
import 'routes.dart';

/// A game as the lobby offers it: its rules and where its screens start.
final class GameEntry {
  /// Creates an entry for [game].
  const GameEntry({
    required this.game,
    required this.route,
    required this.name,
    required this.subtitle,
  });

  /// The game's rules (AGENTS.md §5.4).
  final GameDefinition<Object?, GameAction, PlayerView> game;

  /// Where the game's screens start: setting up a match.
  final String route;

  /// The game's name, in the player's language.
  final String Function(AppLocalizations l10n) name;

  /// One line about how the game is played here.
  final String Function(AppLocalizations l10n) subtitle;
}

/// Every game the app offers, in lobby order (AGENTS.md §5.9). A new game is
/// one more entry here, with its rules package and its screens.
final gameEntriesProvider = Provider<List<GameEntry>>(
  (ref) => [
    GameEntry(
      game: const TwentyNineGame(),
      route: AppRoutes.twentyNine,
      name: (l10n) => l10n.gameTwentyNineName,
      subtitle: (l10n) => l10n.gameTwentyNineSubtitle,
    ),
  ],
);

/// The rules of every game the app offers, by ID.
final gameRegistryProvider = Provider<GameRegistry>(
  (ref) => GameRegistry([
    for (final entry in ref.watch(gameEntriesProvider)) entry.game,
  ]),
);
