import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

/// The rules most scenario tests use: the defaults without redeal checks,
/// so hand-picked deals are never cancelled by accident.
const TwentyNineConfig testConfig = TwentyNineConfig(redealChecks: false);

/// Cards from IDs separated by spaces, for example `'JH 9H 10S'`.
List<Card> cards(String ids) => [
  for (final id in ids.split(' ').where((id) => id.isNotEmpty)) Card.parse(id),
];

/// A deck order that deals [hands] when [dealer] deals.
///
/// Each entry of [hands] lists a seat's cards in the order dealt: the first
/// four come in the first batch, the rest in the second. Seats with fewer
/// than eight cards are filled from the unused cards in deck order.
List<Card> stackedDeck({
  required int dealer,
  Map<int, String> hands = const {},
}) {
  final given = {for (final seat in hands.keys) seat: cards(hands[seat]!)};
  final used = given.values.expand((cards) => cards).toList();
  if (used.toSet().length != used.length) {
    throw ArgumentError('A card is dealt twice: $used');
  }
  final spare = TwentyNineRules.deck.where((c) => !used.contains(c)).toList();
  final full = <int, List<Card>>{};
  for (var seat = 0; seat < 4; seat++) {
    final hand = List.of(given[seat] ?? <Card>[]);
    if (hand.length > 8) throw ArgumentError('Seat $seat has over 8 cards');
    while (hand.length < 8) {
      hand.add(spare.removeAt(0));
    }
    full[seat] = hand;
  }
  final order = <Card>[];
  for (final batch in [0, 4]) {
    for (var i = 1; i <= 4; i++) {
      order.addAll(full[(dealer + i) % 4]!.sublist(batch, batch + 4));
    }
  }
  return order;
}

/// A match driven step by step, collecting every event.
final class Table {
  Table._(this.state) : events = List.of(state.lastEvents);

  /// A match whose first deal gives each seat the cards in [hands]; see
  /// [stackedDeck].
  factory Table.deal({
    Map<int, String> hands = const {},
    int dealer = 3,
    TwentyNineConfig config = testConfig,
    int seed = 1,
  }) => Table._(
    game.initWithDeck(
      config.toMatchConfig(),
      seed,
      dealer: Seat(dealer),
      deck: stackedDeck(dealer: dealer, hands: hands),
    ),
  );

  /// A match shuffled from [seed].
  factory Table.seeded(int seed, {TwentyNineConfig config = testConfig}) =>
      Table._(game.init(config.toMatchConfig(), seed));

  /// The rules.
  static const TwentyNineGame game = TwentyNineGame();

  /// The current state.
  TwentyNineState state;

  /// Every event since the match started.
  final List<TwentyNineEvent> events;

  /// The seat whose decision is awaited.
  Seat get turn => state.turn!;

  /// The seat that won the auction.
  Seat get bidder => state.bidder!;

  /// Applies [action].
  void act(TwentyNineAction action) {
    state = game.apply(state, action);
    events.addAll(state.lastEvents);
  }

  /// Applies [actions] in order.
  void actAll(Iterable<TwentyNineAction> actions) => actions.forEach(act);

  /// The legal actions of [seat], by default the seat to act.
  List<TwentyNineAction> legal([int? seat]) =>
      game.legalActions(state, seat == null ? turn : Seat(seat));

  /// The cards [seat] may play now, as IDs separated by spaces.
  String playable([int? seat]) => [
    for (final action in legal(seat))
      if (action is PlayCard) action.card.id,
  ].join(' ');

  /// What [seat] sees.
  TwentyNineView view(int seat) => game.viewFor(state, Seat(seat));

  /// The events of type [T] so far.
  List<T> eventsOf<T extends TwentyNineEvent>() =>
      events.whereType<T>().toList();

  /// Runs an auction that [winner] wins with [bid]: everyone else passes.
  void auction(int winner, int bid) {
    while (state.phase == TwentyNinePhase.auction) {
      final seat = turn;
      act(seat.index == winner ? Bid(seat, bid) : Pass(seat));
    }
  }

  /// The bidder names [suit] as trump.
  void chooseTrump(String suit) =>
      act(ChooseTrump(bidder, Suit.tryParse(suit)!));

  /// Both opponents decline to double.
  void noDoubles() {
    act(NoDouble(turn));
    act(NoDouble(turn));
  }

  /// Auction to [winner] at [bid], trump [suit], no doubles: play begins.
  void startPlay({int winner = 0, int bid = 16, String suit = 'C'}) {
    auction(winner, bid);
    chooseTrump(suit);
    if (state.config.doubleRedouble) noDoubles();
  }

  /// Plays [ids] in order, each by the seat whose turn it is.
  void play(String ids) {
    for (final card in cards(ids)) {
      act(PlayCard(turn, card));
    }
  }

  /// The seat to act asks for trump.
  void ask() => act(AskTrump(turn));
}

/// A random legal action for property tests. Passes half the time when
/// passing is allowed, so auctions end at realistic bids and all-pass
/// deals happen.
TwentyNineAction randomAction(
  List<TwentyNineAction> legal,
  Xoshiro256StarStar rng,
) {
  if (rng.nextBounded(2) == 0) {
    for (final action in legal) {
      if (action is Pass) return action;
    }
  }
  return legal[rng.nextBounded(legal.length)];
}
