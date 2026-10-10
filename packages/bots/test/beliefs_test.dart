import 'package:bots/src/twentynine/beliefs.dart';
import 'package:bots/src/twentynine/cards.dart';
import 'package:bots/src/twentynine/knowledge.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'search_test.dart' show playPosition, trueWorld;
import 'support.dart';

/// Whether [world] fits everything [k] knows, as dealt.
bool consistent(World world, Knowledge k) {
  var all = 0;
  for (var seat = 0; seat < 4; seat++) {
    final hand = world.hands[seat];
    if (all & hand != 0) return false;
    all |= hand;
    if (seat == k.me) {
      if (hand != k.hand) return false;
      continue;
    }
    if (C29.count(hand) != k.handSizes[seat]) return false;
    // A void says nothing about a card whose place is known: a seventh
    // card set aside when the bidder could not follow joins the hand once
    // revealed.
    var placed = 0;
    for (final card in k.placed.keys) {
      placed |= 1 << card;
    }
    for (var suit = 0; suit < 4; suit++) {
      if (k.voidSuits[seat] & (1 << suit) != 0 &&
          hand & ~placed & C29.suitMask(suit) != 0) {
        return false;
      }
    }
  }
  for (final MapEntry(key: card, value: seat) in k.placed.entries) {
    if (!C29.has(world.hands[seat], card)) return false;
  }
  final seventh = world.seventh >= 0 ? 1 << world.seventh : 0;
  // Every card still to play: the bot's own, those it cannot see, and those
  // it knows the place of, such as a revealed seventh card in the bidder's
  // hand.
  var expected = k.hand | k.unseen;
  if (k.ownSeventh >= 0) expected |= 1 << k.ownSeventh;
  for (final card in k.placed.keys) {
    expected |= 1 << card;
  }
  return (all | seventh) == expected && (k.trump < 0 || world.trump == k.trump);
}

void main() {
  group('the exact endgame (AGENTS.md §8.3.6)', () {
    test('lists every possible deal once, the real one among them', () {
      final random = Xoshiro256StarStar.seeded(301);
      var checked = 0;
      while (checked < 40) {
        final state = playPosition(random, tricks: 5);
        final seat = state.turn!;
        final view = game.viewFor(state, seat);
        final k = Knowledge.of(view, inference: true);
        final worlds = Beliefs(view, k, soft: false).enumerate(100000);
        if (worlds == null) continue;
        final keys = <String>{};
        for (final (:world, :weight) in worlds) {
          expect(consistent(world, k), isTrue);
          expect(weight, greaterThan(0));
          expect(
            keys.add('${world.hands} ${world.seventh} ${world.trump}'),
            isTrue,
            reason: 'listed once',
          );
        }
        final real = trueWorld(state);
        final realHands = [
          for (var s = 0; s < 4; s++) s == seat.index ? k.hand : real.hands[s],
        ];
        expect(
          worlds.any(
            (w) =>
                '${w.world.hands}' == '$realHands' &&
                (k.trump >= 0 ? w.world.trump == real.trump : true),
          ),
          isTrue,
          reason: 'the real deal is possible',
        );
        checked++;
      }
    });

    test('gives up when there are more deals than the limit', () {
      final random = Xoshiro256StarStar.seeded(302);
      final state = playPosition(random);
      final view = game.viewFor(state, state.turn!);
      final k = Knowledge.of(view, inference: true);
      expect(Beliefs(view, k, soft: false).enumerate(50), isNull);
    });
  });

  group('beliefs (AGENTS.md §8.3.1)', () {
    final view = game.viewFor(
      playPosition(Xoshiro256StarStar.seeded(303)),
      const Seat(0),
    );
    final k = Knowledge.of(view, inference: true);

    test('a hidden trump is likeliest the suit the bidder is long in', () {
      final hand = C29.maskOf(cards('JH 9H AH 7H 8H 7S 8S 7C'));
      final even = Beliefs(view, k, soft: false).trumpChances(hand);
      expect(even, [0.0, 1.0, 0.0, 0.0], reason: 'spades, hearts, ...');
      final soft = Beliefs(view, k, soft: true).trumpChances(hand);
      expect(soft.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
      expect(soft[Suit.hearts.index], greaterThan(0.9));
      expect(soft[Suit.spades.index], greaterThan(soft[Suit.diamonds.index]));
    });

    test('without soft beliefs every deal weighs the same', () {
      final worlds = Beliefs(
        view,
        k,
        soft: false,
      ).sample(Xoshiro256StarStar.seeded(1), 20);
      expect(worlds, hasLength(20));
      expect(worlds.every((w) => w.weight == 1), isTrue);
      expect(worlds.every((w) => consistent(w.world, k)), isTrue);
    });

    test('soft samples still fit what the bot knows', () {
      final worlds = Beliefs(
        view,
        k,
        soft: true,
      ).sample(Xoshiro256StarStar.seeded(2), 30);
      expect(worlds, hasLength(30));
      expect(worlds.every((w) => consistent(w.world, k)), isTrue);
    });
  });

  test('a bidder is likelier strong and a passer weak', () {
    // Seat 1 bids 18, seat 2 passes; seat 0 deals in this first deal.
    final state = applyAll(dealHands({}, dealer: 0), const [
      Bid(Seat(1), 18),
      Pass(Seat(2)),
    ]);
    final view = game.viewFor(state, const Seat(3));
    final k = Knowledge.of(view, inference: true);
    final beliefs = Beliefs(view, k, soft: true);
    final strong = C29.maskOf(cards('JS 9S AS JH 9H AH 10H JD'));
    final weak = C29.maskOf(cards('7S 8S 7H 8H 7D 8D 7C 8C'));
    List<int> deal(int bidder, int passer) => [0, bidder, passer, k.hand];
    expect(
      beliefs.auctionFit(deal(strong, weak), -1),
      greaterThan(beliefs.auctionFit(deal(weak, strong), -1)),
    );
    expect(Beliefs(view, k, soft: false).auctionFit(deal(weak, strong), -1), 1);
  });
}
