import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import '../../../l10n/app_localizations.dart';

/// Where a seat sits on the player's screen.
enum ScreenSide {
  /// The player.
  bottom,

  /// The player's partner.
  top,

  /// An opponent on the left.
  left,

  /// An opponent on the right.
  right,
}

/// The side of the screen for [seat] when the player sits in [me]
/// (AGENTS.md §5.10): the player at the bottom and the partner at the top.
/// With play counter-clockwise the next player sits on the right; clockwise,
/// on the left.
ScreenSide sideOf(
  Seat seat, {
  required Seat me,
  required PlayDirection direction,
}) {
  final steps = (seat.index - me.index) % TwentyNineRules.seatCount;
  final counterClockwise = direction == PlayDirection.counterClockwise;
  return switch (steps) {
    0 => ScreenSide.bottom,
    2 => ScreenSide.top,
    1 => counterClockwise ? ScreenSide.right : ScreenSide.left,
    _ => counterClockwise ? ScreenSide.left : ScreenSide.right,
  };
}

/// How the player names a seat: You, Partner, Left or Right.
String seatName(
  AppLocalizations l10n,
  Seat seat, {
  required Seat me,
  required PlayDirection direction,
}) => switch (sideOf(seat, me: me, direction: direction)) {
  ScreenSide.bottom => l10n.seatYou,
  ScreenSide.top => l10n.seatPartner,
  ScreenSide.left => l10n.seatLeft,
  ScreenSide.right => l10n.seatRight,
};

/// The player's cards in display order: suits alternate black and red
/// (spades, hearts, clubs, diamonds), strongest first within a suit.
List<Card> sortedHand(Iterable<Card> cards) {
  const suitOrder = [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];
  return [...cards]..sort((a, b) {
    final bySuit = suitOrder.indexOf(a.suit) - suitOrder.indexOf(b.suit);
    if (bySuit != 0) return bySuit;
    return TwentyNineRules.power(b.rank) - TwentyNineRules.power(a.rank);
  });
}
