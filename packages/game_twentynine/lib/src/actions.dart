import 'package:game_core/game_core.dart';

import 'rules.dart';

/// A decision by one player in Twenty-Nine.
///
/// Two actions are equal when they have the same type, seat and data, so a
/// list of legal actions can be searched with `contains`.
sealed class TwentyNineAction implements GameAction {
  const TwentyNineAction(this.seat);

  /// Reads an action written by [toJson].
  ///
  /// Throws a [FormatException] if [json] is not a valid action.
  factory TwentyNineAction.fromJson(Map<String, Object?> json) {
    final seatIndex = json['seat'];
    if (seatIndex is! int ||
        seatIndex < 0 ||
        seatIndex >= TwentyNineRules.seatCount) {
      throw FormatException('Action seat must be 0 to 3, not $seatIndex');
    }
    final seat = Seat(seatIndex);
    return switch (json['type']) {
      'bid' => Bid(seat, _intField(json, 'value')),
      'matchBid' => MatchBid(seat, _intField(json, 'value')),
      'pass' => Pass(seat),
      'chooseTrump' => ChooseTrump(seat, _suitField(json)),
      'callSeventhCard' => CallSeventhCard(seat),
      'double' => Double(seat),
      'noDouble' => NoDouble(seat),
      'redouble' => Redouble(seat),
      'noRedouble' => NoRedouble(seat),
      'declareSingleHand' => DeclareSingleHand(seat),
      'noSingleHand' => NoSingleHand(seat),
      'playCard' => PlayCard(seat, _cardField(json)),
      'askTrump' => AskTrump(seat),
      'declarePair' => DeclarePair(seat),
      'noPair' => NoPair(seat),
      final type => throw FormatException('Unknown action type: $type'),
    };
  }

  /// The action a logged event records, or null for an event the rules
  /// produced on their own.
  ///
  /// [type] is the event type, such as `twentynine.cardPlayed`; [actor] is
  /// the seat ID, such as `seat:2`; [payload] is the event's data. Used to
  /// replay a match from its event log (AGENTS.md §9). Throws a
  /// [FormatException] for a malformed action event.
  static TwentyNineAction? fromEvent(
    String type,
    String actor,
    Map<String, Object?> payload,
  ) {
    const prefix = 'twentynine.';
    if (!type.startsWith(prefix)) return null;
    final actionType = _actionTypes[type.substring(prefix.length)];
    if (actionType == null) return null;
    return TwentyNineAction.fromJson({
      ...payload,
      'type': actionType,
      'seat': Seat.parse(actor).index,
    });
  }

  /// Action types by the name of the event that records them.
  static const Map<String, String> _actionTypes = {
    'bid': 'bid',
    'bidMatched': 'matchBid',
    'passed': 'pass',
    'trumpChosen': 'chooseTrump',
    'seventhCardCalled': 'callSeventhCard',
    'doubled': 'double',
    'doubleDeclined': 'noDouble',
    'redoubled': 'redouble',
    'redoubleDeclined': 'noRedouble',
    'singleHandDeclared': 'declareSingleHand',
    'singleHandDeclined': 'noSingleHand',
    'cardPlayed': 'playCard',
    'trumpAsked': 'askTrump',
    'pairDeclared': 'declarePair',
    'pairDeclined': 'noPair',
  };

  @override
  final Seat seat;

  /// The action's type in JSON, for example `playCard`.
  String get type;

  /// The type of the event that records the action, for example
  /// `cardPlayed` (AGENTS.md §9).
  String get eventName;

  /// The action's data without its type and seat, for example
  /// `{'card': 'JH'}`.
  Map<String, Object?> get data => const {};

  Object? get _detail => null;

  @override
  Map<String, Object?> toJson() => {'type': type, 'seat': seat.index, ...data};

  @override
  bool operator ==(Object other) =>
      other is TwentyNineAction &&
      other.type == type &&
      other.seat == seat &&
      other._detail == _detail;

  @override
  int get hashCode => Object.hash(type, seat, _detail);

  @override
  String toString() {
    final detail = data.values.join(' ');
    return detail.isEmpty ? '${seat.id} $type' : '${seat.id} $type $detail';
  }

  static int _intField(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('$key must be an integer');
    return value;
  }

  static Suit _suitField(Map<String, Object?> json) {
    final letter = json['suit'];
    final suit = letter is String ? Suit.tryParse(letter) : null;
    if (suit == null) throw FormatException('Not a suit: $letter');
    return suit;
  }

  static Card _cardField(Map<String, Object?> json) {
    final id = json['card'];
    final card = id is String ? Card.tryParse(id) : null;
    if (card == null) throw FormatException('Not a card ID: $id');
    return card;
  }
}

/// Bid [value] points in the auction.
final class Bid extends TwentyNineAction {
  /// Creates a bid of [value] by [seat].
  const Bid(super.seat, this.value);

  /// The number of points bid.
  final int value;

  @override
  String get type => 'bid';

  @override
  String get eventName => 'bid';

  @override
  Map<String, Object?> get data => {'value': value};

  @override
  Object? get _detail => value;
}

/// The old bidder matches the new bidder's bid of [value] (AGENTS.md
/// §6.4): the same number, now held by the old bidder.
final class MatchBid extends TwentyNineAction {
  /// Creates a match of [value] by [seat].
  const MatchBid(super.seat, this.value);

  /// The bid matched.
  final int value;

  @override
  String get type => 'matchBid';

  @override
  String get eventName => 'bidMatched';

  @override
  Map<String, Object?> get data => {'value': value};

  @override
  Object? get _detail => value;
}

/// Pass in the auction. A pass is final for the deal.
final class Pass extends TwentyNineAction {
  /// Creates a pass by [seat].
  const Pass(super.seat);

  @override
  String get type => 'pass';

  @override
  String get eventName => 'passed';
}

/// The bidder secretly names [suit] as trump.
final class ChooseTrump extends TwentyNineAction {
  /// Creates the choice of [suit] by [seat].
  const ChooseTrump(super.seat, this.suit);

  /// The trump suit.
  final Suit suit;

  @override
  String get type => 'chooseTrump';

  @override
  String get eventName => 'trumpChosen';

  @override
  Map<String, Object?> get data => {'suit': suit.letter};

  @override
  Object? get _detail => suit;
}

/// The bidder calls "seventh card": their seventh card is set aside face
/// down and its suit is trump.
final class CallSeventhCard extends TwentyNineAction {
  /// Creates the call by [seat].
  const CallSeventhCard(super.seat);

  @override
  String get type => 'callSeventhCard';

  @override
  String get eventName => 'seventhCardCalled';
}

/// An opponent of the bidder doubles the stake.
final class Double extends TwentyNineAction {
  /// Creates the double by [seat].
  const Double(super.seat);

  @override
  String get type => 'double';

  @override
  String get eventName => 'doubled';
}

/// An opponent of the bidder declines to double.
final class NoDouble extends TwentyNineAction {
  /// Creates the refusal by [seat].
  const NoDouble(super.seat);

  @override
  String get type => 'noDouble';

  @override
  String get eventName => 'doubleDeclined';
}

/// The bidder or their partner redoubles the doubled stake.
final class Redouble extends TwentyNineAction {
  /// Creates the redouble by [seat].
  const Redouble(super.seat);

  @override
  String get type => 'redouble';

  @override
  String get eventName => 'redoubled';
}

/// The bidder or their partner declines to redouble.
final class NoRedouble extends TwentyNineAction {
  /// Creates the refusal by [seat].
  const NoRedouble(super.seat);

  @override
  String get type => 'noRedouble';

  @override
  String get eventName => 'redoubleDeclined';
}

/// Declare single hand: win all eight tricks alone.
final class DeclareSingleHand extends TwentyNineAction {
  /// Creates the declaration by [seat].
  const DeclareSingleHand(super.seat);

  @override
  String get type => 'declareSingleHand';

  @override
  String get eventName => 'singleHandDeclared';
}

/// Decline to declare single hand.
final class NoSingleHand extends TwentyNineAction {
  /// Creates the refusal by [seat].
  const NoSingleHand(super.seat);

  @override
  String get type => 'noSingleHand';

  @override
  String get eventName => 'singleHandDeclined';
}

/// Play [card] to the current trick.
final class PlayCard extends TwentyNineAction {
  /// Creates the play of [card] by [seat].
  const PlayCard(super.seat, this.card);

  /// The card played.
  final Card card;

  @override
  String get type => 'playCard';

  @override
  String get eventName => 'cardPlayed';

  @override
  Map<String, Object?> get data => {'card': card.id};

  @override
  Object? get _detail => card;
}

/// Ask for the hidden trump to be shown. Only a player who cannot follow
/// suit may ask; for the bidder this reveals their own trump.
final class AskTrump extends TwentyNineAction {
  /// Creates the request by [seat].
  const AskTrump(super.seat);

  @override
  String get type => 'askTrump';

  @override
  String get eventName => 'trumpAsked';
}

/// Declare the Pair: the King and Queen of trump in one hand.
final class DeclarePair extends TwentyNineAction {
  /// Creates the declaration by [seat].
  const DeclarePair(super.seat);

  @override
  String get type => 'declarePair';

  @override
  String get eventName => 'pairDeclared';
}

/// Decline to declare the Pair for now.
final class NoPair extends TwentyNineAction {
  /// Creates the refusal by [seat].
  const NoPair(super.seat);

  @override
  String get type => 'noPair';

  @override
  String get eventName => 'pairDeclined';
}
