import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

/// Fast card arithmetic for the Twenty-Nine bots.
///
/// A card is an index from 0 to 31: suit * 8 + slot, with slots in the order
/// 7 8 9 10 J Q K A, which is the order of [TwentyNineRules.deck]. A set of
/// cards is a bit mask with bit `i` for card `i`.
abstract final class C29 {
  /// The index of [card].
  static int index(Card card) =>
      card.suit.index * 8 + card.rank.index - Rank.seven.index;

  /// The card at [index].
  static Card card(int index) => TwentyNineRules.deck[index];

  /// The mask of [cards].
  static int maskOf(Iterable<Card> cards) {
    var mask = 0;
    for (final card in cards) {
      mask |= 1 << index(card);
    }
    return mask;
  }

  /// The suit index of card [index].
  static int suitOf(int index) => index >> 3;

  /// The strength of card [index] within its suit: J 7, 9 6, A 5, 10 4,
  /// K 3, Q 2, 8 1, 7 0.
  static int power(int index) => _power[index & 7];

  /// The card points of card [index].
  static int points(int index) => _points[index & 7];

  static const List<int> _power = [0, 1, 6, 4, 7, 2, 3, 5];
  static const List<int> _points = [0, 0, 2, 1, 3, 0, 0, 1];

  /// Slots from strongest to weakest: J 9 A 10 K Q 8 7.
  static const List<int> slotsByPower = [4, 2, 7, 3, 6, 5, 1, 0];

  /// Every card of [suit].
  static int suitMask(int suit) => 0xFF << (suit * 8);

  /// Whether [mask] holds card [index].
  static bool has(int mask, int index) => mask & (1 << index) != 0;

  /// How many cards [mask] holds.
  static int count(int mask) {
    var m = mask - ((mask >> 1) & 0x55555555);
    m = (m & 0x33333333) + ((m >> 2) & 0x33333333);
    m = (m + (m >> 4)) & 0x0F0F0F0F;
    return ((m * 0x01010101) & 0xFFFFFFFF) >> 24;
  }

  /// The cards of [mask], lowest index first.
  static List<int> list(int mask) => [
    for (var i = 0; i < 32; i++)
      if (mask & (1 << i) != 0) i,
  ];

  /// The card points in [mask].
  static int pointsOf(int mask) {
    var total = 0;
    for (var i = 0; i < 32; i++) {
      if (mask & (1 << i) != 0) total += points(i);
    }
    return total;
  }

  /// The strongest card of [suit] in [mask], or -1 if there is none.
  static int strongest(int mask, int suit) {
    for (final slot in slotsByPower) {
      final card = suit * 8 + slot;
      if (mask & (1 << card) != 0) return card;
    }
    return -1;
  }

  /// The weakest card of [suit] in [mask], or -1 if there is none.
  static int weakest(int mask, int suit) {
    for (var i = slotsByPower.length - 1; i >= 0; i--) {
      final card = suit * 8 + slotsByPower[i];
      if (mask & (1 << card) != 0) return card;
    }
    return -1;
  }

  /// The card of [mask] that is cheapest to give away: fewest points, then
  /// least strength, then lowest index. -1 if [mask] is empty.
  static int cheapest(int mask) {
    var best = -1;
    for (var i = 0; i < 32; i++) {
      if (mask & (1 << i) == 0) continue;
      if (best < 0 ||
          points(i) < points(best) ||
          (points(i) == points(best) && power(i) < power(best))) {
        best = i;
      }
    }
    return best;
  }

  /// The card of [mask] worth most points, then strongest. -1 if empty.
  static int richest(int mask) {
    var best = -1;
    for (var i = 0; i < 32; i++) {
      if (mask & (1 << i) == 0) continue;
      if (best < 0 ||
          points(i) > points(best) ||
          (points(i) == points(best) && power(i) > power(best))) {
        best = i;
      }
    }
    return best;
  }

  /// The least strong card of [mask], whatever its suit; -1 if empty.
  static int leastPower(int mask) {
    var best = -1;
    for (var i = 0; i < 32; i++) {
      if (mask & (1 << i) == 0) continue;
      if (best < 0 || power(i) < power(best)) best = i;
    }
    return best;
  }
}
