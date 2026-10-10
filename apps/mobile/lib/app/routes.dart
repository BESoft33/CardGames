/// Route locations. Navigate with these instead of string literals.
abstract final class AppRoutes {
  /// The lobby, where the player picks a game.
  static const String lobby = '/';

  /// Setting up a match of Twenty-Nine.
  static const String twentyNine = '/twentynine';

  /// The table of the current Twenty-Nine match.
  static const String twentyNineTable = '/twentynine/table';

  /// The player's Earned Coins: confirmed and pending.
  static const String wallet = '/wallet';

  /// The player's settings, such as the table fee.
  static const String settings = '/settings';

  /// Every card image, for checking the owner's card art. Debug builds only.
  static const String cardGallery = '/debug/cards';
}
