import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

const TwentyNineGame game = TwentyNineGame();

/// Rules for the fair-play tests: no redeal checks and no all-pass redeal,
/// so a deal is never reshuffled and can be rebuilt on a changed deck.
const TwentyNineConfig fixedDealConfig = TwentyNineConfig(redealChecks: false);

/// A position in the first deal of a match, with what is needed to reach it
/// again on another deck.
final class Position {
  Position(this.dealer, this.deck, this.seed, this.actions, this.state);

  /// The dealer of the first deal.
  final Seat dealer;

  /// The deck order of the first deal.
  final List<Card> deck;

  /// The match seed.
  final int seed;

  /// The actions taken since the deal began.
  final List<TwentyNineAction> actions;

  /// The position reached.
  final TwentyNineState state;

  /// The seat about to decide.
  Seat get seat => state.turn!;

  /// The state reached by the same actions on [deck], from [seed].
  TwentyNineState replay(List<Card> deck, int seed) {
    var state = game.initWithDeck(
      fixedDealConfig.toMatchConfig(),
      seed,
      dealer: dealer,
      deck: deck,
    );
    for (final action in actions) {
      state = game.apply(state, action);
    }
    return state;
  }
}

/// A random position in the first deal where the seat to act has more than
/// one legal action.
Position randomPosition(Xoshiro256StarStar random) {
  for (;;) {
    final deck = List.of(TwentyNineRules.deck);
    shuffleInPlace(deck, random);
    final dealer = Seat(random.nextBounded(4));
    final seed = random.nextInt64();
    var state = game.initWithDeck(
      fixedDealConfig.toMatchConfig(),
      seed,
      dealer: dealer,
      deck: deck,
    );
    final actions = <TwentyNineAction>[];
    final stop = random.nextBounded(45);
    var ended = false;
    for (var step = 0; ; step++) {
      final legal = game.legalActions(state, state.turn!);
      if (step >= stop && legal.length > 1) break;
      final action = legal[random.nextBounded(legal.length)];
      final next = game.apply(state, action);
      if (next.dealNumber != 1 || next.isOver) {
        ended = true;
        break;
      }
      state = next;
      actions.add(action);
    }
    if (!ended) return Position(dealer, deck, seed, actions, state);
  }
}

/// Where each card the viewer cannot see lies: a seat's hand (0-3), the
/// undealt cards (4) or the set-aside seventh card (5). A revealed seventh
/// card is public even in the bidder's hand, so it is left out.
Map<Card, int> hiddenCards(TwentyNineState state, Seat viewer) {
  final visible = visibleCards(state, viewer);
  final places = <Card, int>{};
  for (var seat = 0; seat < 4; seat++) {
    if (seat == viewer.index) continue;
    for (final card in state.hands[seat]) {
      if (!visible.contains(card)) places[card] = seat;
    }
  }
  for (final card in state.undealt) {
    places[card] = 4;
  }
  if (state.seventhCardSetAside && state.bidder != viewer) {
    places[state.seventhCard!] = 5;
  }
  return places;
}

/// [position]'s deck with hidden cards swapped between places the viewer
/// cannot see: up to [swaps] swaps, each of two cards of one suit, so every
/// action taken so far stays legal. The King and Queen of trump stay put,
/// so a Pair offer cannot move. Null if no swap is possible.
List<Card>? swapHiddenCards(
  Position position,
  Xoshiro256StarStar random, {
  int swaps = 1,
}) {
  final state = position.state;
  final places = hiddenCards(state, position.seat);
  final trump = state.trumpSuit;
  final movable = places.keys
      .where(
        (card) =>
            card.suit != trump ||
            (card.rank != Rank.king && card.rank != Rank.queen),
      )
      .toList();
  final pairs = <(Card, Card)>[];
  for (var i = 0; i < movable.length; i++) {
    for (var j = i + 1; j < movable.length; j++) {
      final a = movable[i];
      final b = movable[j];
      if (a.suit == b.suit && places[a] != places[b]) pairs.add((a, b));
    }
  }
  if (pairs.isEmpty) return null;
  final deck = List.of(position.deck);
  for (var n = 0; n < swaps; n++) {
    final (a, b) = pairs[random.nextBounded(pairs.length)];
    final i = deck.indexOf(a);
    final j = deck.indexOf(b);
    deck[i] = b;
    deck[j] = a;
  }
  return deck;
}

/// Every card the player in [viewer] may see: their hand, the cards
/// played, and the seventh card if revealed or theirs.
Set<Card> visibleCards(TwentyNineState state, Seat viewer) => {
  ...state.hands[viewer.index],
  for (final trick in state.tricks)
    for (final play in trick.plays) play.card,
  for (final play in state.trick) play.card,
  if (state.seventhCard case final seventh?)
    if (state.trumpRevealed || state.bidder == viewer) seventh,
};

/// Cards from IDs separated by spaces.
List<Card> cards(String ids) => [
  for (final id in ids.split(' ').where((id) => id.isNotEmpty)) Card.parse(id),
];

/// A first deal giving each seat the cards in [hands] (in the order dealt;
/// short hands are filled from the unused cards in deck order), dealt by
/// [dealer].
TwentyNineState dealHands(
  Map<int, String> hands, {
  int dealer = 3,
  TwentyNineConfig config = fixedDealConfig,
}) {
  final given = {for (final seat in hands.keys) seat: cards(hands[seat]!)};
  final used = given.values.expand((c) => c).toSet();
  final spare = TwentyNineRules.deck.where((c) => !used.contains(c)).toList();
  final full = {
    for (var seat = 0; seat < 4; seat++)
      seat: [
        ...?given[seat],
        for (var i = given[seat]?.length ?? 0; i < 8; i++) spare.removeAt(0),
      ],
  };
  final deck = [
    for (final batch in [0, 4])
      for (var i = 1; i <= 4; i++)
        ...full[(dealer + i) % 4]!.sublist(batch, batch + 4),
  ];
  return game.initWithDeck(
    config.toMatchConfig(),
    1,
    dealer: Seat(dealer),
    deck: deck,
  );
}

/// Applies [actions] to [state] in order.
TwentyNineState applyAll(
  TwentyNineState state,
  Iterable<TwentyNineAction> actions,
) => actions.fold(state, game.apply);

/// Everyone passes so the dealer must bid; the dealer names [suit]; nobody
/// doubles. Returns the state at the first lead.
TwentyNineState forcedDealerPlays(TwentyNineState state, Suit suit) {
  var s = state;
  while (s.phase == TwentyNinePhase.auction) {
    final legal = game.legalActions(s, s.turn!);
    s = game.apply(s, legal.whereType<Pass>().firstOrNull ?? legal.first);
  }
  s = game.apply(s, ChooseTrump(s.bidder!, suit));
  while (s.phase == TwentyNinePhase.doubling ||
      s.phase == TwentyNinePhase.redoubling) {
    final legal = game.legalActions(s, s.turn!);
    s = game.apply(s, legal.last);
  }
  return s;
}

/// [state] after the seat to act plays each card in [ids], in turn.
TwentyNineState playCards(TwentyNineState state, String ids) {
  var s = state;
  for (final card in cards(ids)) {
    s = game.apply(s, PlayCard(s.turn!, card));
  }
  return s;
}
