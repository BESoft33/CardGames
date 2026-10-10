/// A suit. Card IDs use the letters S, H, D and C, in that order.
enum Suit {
  spades('S', isRed: false),
  hearts('H', isRed: true),
  diamonds('D', isRed: true),
  clubs('C', isRed: false);

  const Suit(this.letter, {required this.isRed});

  /// The letter used in card IDs.
  final String letter;

  /// Whether the suit is printed in red.
  final bool isRed;

  /// Returns the suit written as [letter], or null if there is none.
  static Suit? tryParse(String letter) {
    for (final suit in values) {
      if (suit.letter == letter) return suit;
    }
    return null;
  }
}

/// A rank of the standard 52-card deck, lowest first.
///
/// Each game defines its own ranking and point values on top of this.
enum Rank {
  two('2'),
  three('3'),
  four('4'),
  five('5'),
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  ten('10'),
  jack('J'),
  queen('Q'),
  king('K'),
  ace('A');

  const Rank(this.symbol);

  /// The symbol used in card IDs.
  final String symbol;

  /// Returns the rank written as [symbol], or null if there is none.
  static Rank? tryParse(String symbol) {
    for (final rank in values) {
      if (rank.symbol == symbol) return rank;
    }
    return null;
  }
}

/// A playing card from the standard 52-card deck.
///
/// Its [id] is the rank symbol followed by the suit letter, for example `JH`,
/// `10S` or `7C`. [Card.new] and [Card.parse] return one shared instance per
/// card. Equality compares [index], so a card stays equal to itself after it
/// is serialised and parsed back, for example across an isolate boundary.
final class Card implements Comparable<Card> {
  Card._(this.rank, this.suit)
    : index = suit.index * Rank.values.length + rank.index,
      id = '${rank.symbol}${suit.letter}';

  /// Returns the card of [rank] and [suit].
  factory Card(Rank rank, Suit suit) =>
      values[suit.index * Rank.values.length + rank.index];

  /// Parses a card ID such as `JH` or `10S`.
  ///
  /// Throws a [FormatException] if [id] is not exactly a card ID.
  factory Card.parse(String id) =>
      tryParse(id) ?? (throw FormatException('Not a card ID', id));

  /// Every card, grouped by suit in S, H, D, C order, ranks low to high.
  static final List<Card> values = List.unmodifiable(<Card>[
    for (final suit in Suit.values)
      for (final rank in Rank.values) Card._(rank, suit),
  ]);

  static final Map<String, Card> _byId = {
    for (final card in values) card.id: card,
  };

  /// Parses a card ID, or returns null if [id] is not exactly a card ID.
  static Card? tryParse(String id) => _byId[id];

  /// The card's rank.
  final Rank rank;

  /// The card's suit.
  final Suit suit;

  /// The card's position in [values], from 0 to 51.
  final int index;

  /// The card ID, for example `JH` or `10S`.
  final String id;

  @override
  bool operator ==(Object other) => other is Card && other.index == index;

  @override
  int get hashCode => index;

  /// Orders cards as in [values]. Games apply their own ranking.
  @override
  int compareTo(Card other) => index.compareTo(other.index);

  @override
  String toString() => id;
}
