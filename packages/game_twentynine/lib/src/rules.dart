import 'package:game_core/game_core.dart';

/// Fixed facts of Twenty-Nine (AGENTS.md §6.1).
abstract final class TwentyNineRules {
  /// Number of seats. Teams are seats {0, 2} and {1, 3}.
  static const int seatCount = 4;

  /// Number of tricks in a deal.
  static const int tricksPerDeal = 8;

  /// The 32 cards: 7 to A in each suit, suits in S H D C order.
  static final List<Card> deck = List.unmodifiable(<Card>[
    for (final card in Card.values)
      if (card.rank.index >= Rank.seven.index) card,
  ]);

  /// Card points: J 3, 9 2, A 1, 10 1, K Q 8 7 nothing.
  static int points(Card card) => switch (card.rank) {
    Rank.jack => 3,
    Rank.nine => 2,
    Rank.ace || Rank.ten => 1,
    _ => 0,
  };

  /// Whether [card] is worth points: a J, 9, A or 10.
  static bool isPointCard(Card card) => points(card) > 0;

  /// The strength of [rank] within its suit. Higher wins:
  /// J, 9, A, 10, K, Q, 8, 7.
  static int power(Rank rank) => switch (rank) {
    Rank.jack => 7,
    Rank.nine => 6,
    Rank.ace => 5,
    Rank.ten => 4,
    Rank.king => 3,
    Rank.queen => 2,
    Rank.eight => 1,
    Rank.seven => 0,
    _ => throw ArgumentError.value(rank, 'rank', 'not used in Twenty-Nine'),
  };

  /// The team of [seat]: 0 for seats 0 and 2, 1 for seats 1 and 3.
  static int teamOf(Seat seat) => seat.index % 2;

  /// The two seats of [team].
  static List<Seat> seatsOf(int team) => [Seat(team), Seat(team + 2)];

  /// The player who plays after [seat].
  static Seat next(Seat seat) => seat.next(seatCount);

  /// The partner of [seat], sitting opposite.
  static Seat partnerOf(Seat seat) => seat.offset(2, seatCount);
}
