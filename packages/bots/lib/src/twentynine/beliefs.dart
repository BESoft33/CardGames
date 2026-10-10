import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

import 'cards.dart';
import 'knowledge.dart';

/// A way the unseen cards could lie, and how likely it is relative to the
/// others.
typedef WeightedWorld = ({World world, double weight});

/// What a bot believes about the cards it cannot see (AGENTS.md §8.3.1),
/// beyond the hard facts of [Knowledge]: what the auction says about each
/// hand, and which suit the bidder will have named.
///
/// With [soft] off, every consistent deal is as likely as another and a
/// hidden trump is the bidder's longest suit, as the Skilled bot assumes.
/// With it on, deals are weighted: bidders are likelier to hold strong
/// cards and early passers weak ones, and a hidden trump is likelier to be
/// a suit the bidder is long and strong in.
final class Beliefs {
  /// The beliefs of the seat whose [view] it is.
  Beliefs(this.view, this.k, {required this.soft})
    : _playedBy = _played(view),
      _calls = _bids(view);

  /// The seat's view.
  final TwentyNineView view;

  /// What the view shows for certain.
  final Knowledge k;

  /// Whether the auction and the bidder's likely trump weigh the deals.
  final bool soft;

  final List<int> _playedBy;
  final List<int?> _calls;

  /// Each seat's highest bid, null for a seat that only passed, and -1
  /// for one that never called.
  static List<int?> _bids(TwentyNineView view) {
    final bids = <int?>[-1, -1, -1, -1];
    for (final call in view.calls) {
      final seat = call.seat.index;
      final bid = call.bid;
      final before = bids[seat];
      if (bid != null) {
        bids[seat] = before == null || before < bid ? bid : before;
      } else if (before == -1) {
        bids[seat] = null;
      }
    }
    return bids;
  }

  static List<int> _played(TwentyNineView view) {
    final played = [0, 0, 0, 0];
    for (final trick in view.tricks) {
      for (final play in trick.plays) {
        played[play.seat.index] |= 1 << C29.index(play.card);
      }
    }
    for (final play in view.trick) {
      played[play.seat.index] |= 1 << C29.index(play.card);
    }
    return played;
  }

  /// Every card [seat] held this deal in [hands]: what is left, and what
  /// it has played.
  int dealtTo(int seat, List<int> hands, int seventh) {
    var cards = hands[seat] | _playedBy[seat];
    if (seat == k.bidder && seventh >= 0) cards |= 1 << seventh;
    return cards;
  }

  /// How likely the bidder, holding [cards], was to name each suit as
  /// trump: a share per suit, adding up to 1.
  List<double> trumpChances(int cards) {
    final scores = [
      for (var suit = 0; suit < 4; suit++)
        C29.count(cards & C29.suitMask(suit)) +
            0.5 * C29.pointsOf(cards & C29.suitMask(suit)),
    ];
    if (!soft) {
      // The longest suit, points breaking ties; a remaining tie is split.
      final best = scores.reduce(math.max);
      final ties = scores.where((score) => score == best).length;
      return [for (final score in scores) score == best ? 1.0 / ties : 0.0];
    }
    final top = scores.reduce(math.max);
    final weights = [for (final score in scores) math.exp(score - top)];
    final total = weights.fold(0.0, (a, b) => a + b);
    return [for (final weight in weights) weight / total];
  }

  /// How well the auction fits the hands in [hands]: 1 with [soft] off.
  /// A seat that bid is likelier to be strong, the more so the higher it
  /// bid; a seat that only passed is likelier to be weak.
  double auctionFit(List<int> hands, int seventh) {
    if (!soft) return 1;
    var log = 0.0;
    for (var seat = 0; seat < 4; seat++) {
      if (seat == k.me) continue;
      final call = _calls[seat];
      if (call == -1) continue;
      final cards = dealtTo(seat, hands, seventh);
      // Card points and length: about 11.8 for an average hand.
      var longest = 0;
      for (var suit = 0; suit < 4; suit++) {
        longest = math.max(longest, C29.count(cards & C29.suitMask(suit)));
      }
      final strength = C29.pointsOf(cards) + 1.5 * longest - 11.8;
      log += call == null
          ? -0.08 * strength
          : (0.06 + 0.01 * (call - 15)) * strength;
    }
    return math.exp(log);
  }

  /// The trump of a world dealt as [hands], with the bidder's hidden
  /// [seventh] card: known, the seventh card's suit, or drawn from
  /// [trumpChances] with [random].
  int trumpOf(List<int> hands, int seventh, Xoshiro256StarStar random) {
    if (k.trump >= 0) return k.trump;
    if (seventh >= 0) return C29.suitOf(seventh);
    if (k.bidder < 0) return -1;
    final chances = trumpChances(dealtTo(k.bidder, hands, seventh));
    var pick = unitRandom(random);
    for (var suit = 0; suit < 4; suit++) {
      pick -= chances[suit];
      if (pick < 0) return suit;
    }
    return chances.lastIndexWhere((chance) => chance > 0);
  }

  /// The weight of a world given the trump the bot knows: a trump the
  /// bidder is long and strong in is likelier. 1 with [soft] off, or when
  /// the bot does not know the trump.
  double _knownTrumpFit(List<int> hands, int seventh) {
    if (!soft || k.trump < 0 || k.bidder < 0 || k.bidder == k.me) return 1;
    if (view.seventhCard != null || view.singleHandDeclarer != null) return 1;
    return trumpChances(dealtTo(k.bidder, hands, seventh))[k.trump];
  }

  /// [count] worlds for a search, with their weights. With [soft] off they
  /// are drawn evenly from the consistent deals. With it on, [count] times
  /// [oversample] are drawn evenly and [count] of them kept, picked in
  /// proportion to their weight.
  List<WeightedWorld> sample(
    Xoshiro256StarStar random,
    int count, {
    int oversample = 4,
  }) {
    final drawn = soft ? count * oversample : count;
    final pool = <WeightedWorld>[];
    for (var i = 0; i < drawn; i++) {
      final dealt = dealUnseen(k, random);
      if (dealt == null) continue;
      final (hands, seventh) = dealt;
      final trump = trumpOf(hands, seventh, random);
      pool.add((
        world: World(hands, seventh, trump),
        weight: auctionFit(hands, seventh) * _knownTrumpFit(hands, seventh),
      ));
    }
    if (!soft || pool.isEmpty) return pool;
    final total = pool.fold(0.0, (sum, w) => sum + w.weight);
    if (total <= 0) return pool.take(count).toList();
    // Resampling by weight: each kept world then counts the same.
    return [
      for (var i = 0; i < count; i++)
        (world: _pick(pool, total, random), weight: 1.0),
    ];
  }

  static World _pick(
    List<WeightedWorld> pool,
    double total,
    Xoshiro256StarStar random,
  ) {
    var pick = unitRandom(random) * total;
    for (final entry in pool) {
      pick -= entry.weight;
      if (pick < 0) return entry.world;
    }
    return pool.last.world;
  }

  /// Every way the unseen cards could lie, with its weight, if there are at
  /// most [limit] (AGENTS.md §8.3.6); null otherwise. A world is a deal
  /// and, when the bot does not know it, a trump.
  List<WeightedWorld>? enumerate(int limit) {
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
    final worlds = <WeightedWorld>[];
    var work = 0;
    const workLimit = 200000;

    // Returns false to stop: too many worlds, or too much work.
    bool emit(int seventh) {
      final dealt = List.of(hands);
      final fit = auctionFit(dealt, seventh) * _knownTrumpFit(dealt, seventh);
      if (k.trump >= 0 || seventh >= 0 || k.bidder < 0) {
        final trump = k.trump >= 0
            ? k.trump
            : seventh >= 0
            ? C29.suitOf(seventh)
            : -1;
        worlds.add((world: World(dealt, seventh, trump), weight: fit));
      } else {
        final chances = trumpChances(dealtTo(k.bidder, dealt, seventh));
        for (var suit = 0; suit < 4; suit++) {
          if (chances[suit] > 0) {
            worlds.add((
              world: World(dealt, seventh, suit),
              weight: fit * chances[suit],
            ));
          }
        }
      }
      return worlds.length <= limit;
    }

    bool assign(List<int> cards, int index, int seventh) {
      if (++work > workLimit) return false;
      if (index == cards.length) return emit(seventh);
      final card = cards[index];
      final suitBit = 1 << C29.suitOf(card);
      for (var seat = 0; seat < 4; seat++) {
        if (room[seat] <= 0 || k.voidSuits[seat] & suitBit != 0) continue;
        hands[seat] |= 1 << card;
        room[seat]--;
        final going = assign(cards, index + 1, seventh);
        hands[seat] &= ~(1 << card);
        room[seat]++;
        if (!going) return false;
      }
      return true;
    }

    final bool complete;
    if (k.hiddenSeventh) {
      var ok = true;
      for (final seventh in C29.list(rest)) {
        ok = assign(C29.list(rest & ~(1 << seventh)), 0, seventh);
        if (!ok) break;
      }
      complete = ok;
    } else {
      complete = assign(C29.list(rest), 0, k.ownSeventh);
    }
    return complete && worlds.isNotEmpty ? worlds : null;
  }
}

/// A number from [random] in [0, 1), with 53 random bits.
double unitRandom(Xoshiro256StarStar random) =>
    (random.nextInt64() >>> 11) / 9007199254740992.0;
