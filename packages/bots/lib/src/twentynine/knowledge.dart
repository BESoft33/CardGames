import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import 'cards.dart';
import 'sim.dart';

/// What a bot can work out from its own view (AGENTS.md §8.3): the cards
/// still out, the suits a player cannot hold, and cards whose holder is
/// known. Built from the view alone.
final class Knowledge {
  Knowledge._({
    required this.me,
    required this.hand,
    required this.played,
    required this.unseen,
    required this.voidSuits,
    required this.placed,
    required this.trump,
    required this.bidder,
    required this.hiddenSeventh,
    required this.ownSeventh,
    required this.handSizes,
  });

  /// Works out what [view] shows. With [inference] off, no voids or missing
  /// trumps are deduced.
  factory Knowledge.of(TwentyNineView view, {required bool inference}) {
    final me = view.seat.index;
    final hand = C29.maskOf(view.hand);
    var played = 0;
    for (final trick in view.tricks) {
      for (final play in trick.plays) {
        played |= 1 << C29.index(play.card);
      }
    }
    for (final play in view.trick) {
      played |= 1 << C29.index(play.card);
    }
    final bidder = view.bidder?.index ?? -1;
    final seventhCard = view.seventhCard;
    final seventh = seventhCard == null ? -1 : C29.index(seventhCard);
    var known = hand | played;
    if (seventh >= 0) known |= 1 << seventh;
    final trump = view.trumpSuit?.index ?? -1;
    final placed = <int, int>{};
    // A revealed seventh card not yet played is in the bidder's hand.
    if (seventh >= 0 &&
        bidder != me &&
        !C29.has(played, seventh) &&
        view.trumpRevealed) {
      placed[seventh] = bidder;
    }
    final voids = [0, 0, 0, 0];
    if (inference) {
      void scan(List<TrickPlay> plays) {
        if (plays.isEmpty) return;
        final led = plays.first.card.suit.index;
        for (final play in plays.skip(1)) {
          if (play.card.suit.index != led) voids[play.seat.index] |= 1 << led;
        }
      }

      for (final trick in view.tricks) {
        scan(trick.plays);
      }
      scan(view.trick);

      // A player who asked for trump, and so had to trump if able, but did
      // not play a trump, holds none.
      final asker = view.revealedBy;
      final revealTrick = view.revealTrick;
      if (trump >= 0 &&
          asker != null &&
          revealTrick != null &&
          view.config.askTrump == AskTrumpRule.optional) {
        final plays = revealTrick < view.tricks.length
            ? view.tricks[revealTrick].plays
            : view.trick;
        for (final play in plays) {
          if (play.seat == asker &&
              play.card.suit.index != trump &&
              play.card != seventhCard) {
            voids[asker.index] |= 1 << trump;
          }
        }
      }

      // A declared Pair: the King and Queen of trump stay with the
      // declarer until played.
      final pairBy = view.pairBy;
      if (pairBy != null && pairBy.index != me && trump >= 0) {
        for (final rank in const [Rank.king, Rank.queen]) {
          final card = C29.index(Card(rank, Suit.values[trump]));
          if (!C29.has(known, card)) placed[card] = pairBy.index;
        }
      }
    }
    return Knowledge._(
      me: me,
      hand: hand,
      played: played,
      unseen: 0xFFFFFFFF & ~known,
      voidSuits: voids,
      placed: placed,
      trump: trump,
      bidder: bidder,
      hiddenSeventh: view.seventhCardSetAside && bidder != me,
      ownSeventh: view.seventhCardSetAside && bidder == me ? seventh : -1,
      handSizes: view.handSizes,
    );
  }

  /// The bot's seat.
  final int me;

  /// The bot's cards.
  final int hand;

  /// Every card played in the deal, the current trick included.
  final int played;

  /// The cards the bot cannot see that are still in play.
  final int unseen;

  /// Per seat, the suits it cannot hold in hand, one bit per suit.
  final List<int> voidSuits;

  /// Unplayed cards whose holder is known, by card index.
  final Map<int, int> placed;

  /// The trump suit if the bot knows it, or -1.
  final int trump;

  /// The bidder's seat, or -1 before the auction ends.
  final int bidder;

  /// Whether the bidder has a seventh card set aside that the bot cannot
  /// see.
  final bool hiddenSeventh;

  /// The bot's own set-aside seventh card, or -1.
  final int ownSeventh;

  /// How many cards each seat holds in hand.
  final List<int> handSizes;
}

/// One way the cards the bot cannot see could lie.
final class World {
  /// Creates a world.
  const World(this.hands, this.seventh, this.trump);

  /// Each seat's cards, the bot's own included.
  final List<int> hands;

  /// The bidder's set-aside seventh card, or -1.
  final int seventh;

  /// The trump suit in this world, or -1 if it is unknown and there is no
  /// bidder yet.
  final int trump;
}

/// Deals the unseen cards to the other seats consistently with [k], drawing
/// on [random]. Returns null if no consistent deal turned up.
World? sampleWorld(Knowledge k, Xoshiro256StarStar random) {
  final dealt = dealUnseen(k, random);
  if (dealt == null) return null;
  final (hands, seventh) = dealt;
  final trump = k.trump >= 0
      ? k.trump
      : seventh >= 0
      ? C29.suitOf(seventh)
      : k.bidder >= 0
      ? longestSuit(hands[k.bidder], random)
      : -1;
  return World(hands, seventh, trump);
}

/// Deals the unseen cards to the other seats consistently with [k], drawing
/// on [random]: every seat's hand and the bidder's hidden seventh card (-1
/// if none). Voids are respected if any of 40 tries manages it. Null if no
/// consistent deal turned up.
(List<int>, int)? dealUnseen(Knowledge k, Xoshiro256StarStar random) {
  for (var attempt = 0; attempt < 40; attempt++) {
    final dealt = _deal(k, random, respectVoids: true);
    if (dealt != null) return dealt;
  }
  return _deal(k, random, respectVoids: false);
}

(List<int>, int)? _deal(
  Knowledge k,
  Xoshiro256StarStar random, {
  required bool respectVoids,
}) {
  final hands = [0, 0, 0, 0];
  hands[k.me] = k.hand;
  final room = List.of(k.handSizes);
  room[k.me] = 0;
  var rest = k.unseen;
  for (final MapEntry(key: card, value: seat) in k.placed.entries) {
    hands[seat] |= 1 << card;
    room[seat]--;
    rest &= ~(1 << card);
  }
  var seventh = k.ownSeventh;
  if (k.hiddenSeventh) {
    final cards = C29.list(rest);
    if (cards.isEmpty) return null;
    seventh = cards[random.nextBounded(cards.length)];
    rest &= ~(1 << seventh);
  }

  final cards = C29.list(rest);
  shuffleInPlace(cards, random);
  int choices(int card) {
    var n = 0;
    for (var seat = 0; seat < 4; seat++) {
      if (room[seat] > 0 &&
          !(respectVoids && k.voidSuits[seat] & (1 << C29.suitOf(card)) != 0)) {
        n++;
      }
    }
    return n;
  }

  // Place the most constrained cards first.
  final order = [for (final card in cards) (card, choices(card))]
    ..sort((a, b) => a.$2.compareTo(b.$2));
  for (final (card, _) in order) {
    final suitBit = 1 << C29.suitOf(card);
    var total = 0;
    for (var seat = 0; seat < 4; seat++) {
      if (room[seat] > 0 &&
          !(respectVoids && k.voidSuits[seat] & suitBit != 0)) {
        total += room[seat];
      }
    }
    if (total == 0) return null;
    var pick = random.nextBounded(total);
    for (var seat = 0; seat < 4; seat++) {
      if (room[seat] <= 0 ||
          (respectVoids && k.voidSuits[seat] & suitBit != 0)) {
        continue;
      }
      if (pick < room[seat]) {
        hands[seat] |= 1 << card;
        room[seat]--;
        break;
      }
      pick -= room[seat];
    }
  }

  return (hands, seventh);
}

/// The suit with most cards in [hand]; ties broken by points, then at
/// random. A bidder usually names a suit they are long in.
int longestSuit(int hand, Xoshiro256StarStar random) {
  var best = -1;
  var bestScore = -1;
  var ties = 0;
  for (var suit = 0; suit < 4; suit++) {
    final cards = hand & C29.suitMask(suit);
    final score = C29.count(cards) * 16 + C29.pointsOf(cards);
    if (score > bestScore) {
      best = suit;
      bestScore = score;
      ties = 1;
    } else if (score == bestScore) {
      ties++;
      if (random.nextBounded(ties) == 0) best = suit;
    }
  }
  return best;
}

/// A [Sim] of the position in [view] with the unseen cards dealt as in
/// [world].
Sim simulate(TwentyNineView view, Knowledge k, World world) {
  final config = view.config;
  final sim = Sim(
    hands: List.of(world.hands),
    trump: world.trump,
    revealed: view.trumpRevealed,
    bidder: view.bidder?.index ?? view.firstPlayer.index,
    leader: view.trickLeader?.index ?? view.firstPlayer.index,
    declarer: view.singleHandDeclarer?.index ?? -1,
    seventh: view.seventhCardSetAside ? world.seventh : -1,
    dutyToTrump: config.askTrump == AskTrumpRule.optional,
    mustAsk: config.askTrump == AskTrumpRule.mandatory,
    lastTrickPoint: config.lastTrickPoint,
    played: k.played,
    tricksDone: view.tricks.length,
  );
  sim.points[0] = view.cardPoints[0];
  sim.points[1] = view.cardPoints[1];
  for (final play in view.trick) {
    sim.addToTrick(play.seat.index, C29.index(play.card));
  }
  sim
    ..mustTrump = view.mustTrump?.index ?? -1
    ..trumpFrom = trumpCountsFrom(view);
  return sim;
}

/// The position in [view]'s current trick from which trump-suit cards are
/// trumps (AGENTS.md §6.9): 0 when trump was revealed before the trick; the
/// revealer's card when it was revealed during it, which is the next card
/// if the revealer has not played yet; [Sim.noTrump] while it is hidden.
int trumpCountsFrom(TwentyNineView view) {
  if (!view.trumpRevealed || view.singleHandDeclarer != null) {
    return Sim.noTrump;
  }
  if (view.revealTrick != view.tricks.length) return 0;
  final position = view.trick.indexWhere(
    (play) => play.seat == view.revealedBy,
  );
  return position >= 0 ? position : view.trick.length;
}
