import 'package:bots/src/twentynine/cards.dart';
import 'package:bots/src/twentynine/knowledge.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'support.dart';

Knowledge know(TwentyNineState state, int seat, {bool inference = true}) =>
    Knowledge.of(game.viewFor(state, Seat(seat)), inference: inference);

int suitBit(Suit suit) => 1 << suit.index;

void main() {
  // Seat 3 deals; seat 0 bids 16 with hearts as trump.
  TwentyNineState started(Map<int, String> hands) =>
      applyAll(dealHands(hands), const [
        Bid(Seat(0), 16),
        Pass(Seat(1)),
        Pass(Seat(2)),
        Pass(Seat(3)),
        ChooseTrump(Seat(0), Suit.hearts),
        NoDouble(Seat(1)),
        NoDouble(Seat(3)),
      ]);

  const hands = {
    0: 'JS 9S AS 10S JH 9H 7D 8D',
    1: 'KS QS 8S 7S AH 10H KH QH',
    2: 'JD 9D AD 10D 8H 7H KD QD',
    3: 'JC 9C AC 10C KC QC 8C 7C',
  };

  test('a player who does not follow suit is void in it', () {
    final state = playCards(started(hands), 'JS 7S 8H 7C');
    final k = know(state, 1);
    expect(k.voidSuits[2] & suitBit(Suit.spades), isNot(0));
    expect(k.voidSuits[3] & suitBit(Suit.spades), isNot(0));
    expect(k.voidSuits[1], 0);
    expect(know(state, 1, inference: false).voidSuits, [0, 0, 0, 0]);
  });

  test('an asker who does not trump holds no trump', () {
    // Seat 3 holds only clubs: it asks, hearts are trump, it plays a club.
    var state = playCards(started(hands), 'JS 7S 8H');
    state = game.apply(state, const AskTrump(Seat(3)));
    state = playCards(state, '7C');
    final k = know(state, 0);
    expect(k.voidSuits[3] & suitBit(Suit.hearts), isNot(0));
    expect(k.trump, Suit.hearts.index);
  });

  test('cards out are everything not seen', () {
    final state = playCards(started(hands), 'JS 7S');
    final k = know(state, 2);
    expect(C29.count(k.hand), 8);
    expect(C29.count(k.played), 2);
    expect(C29.count(k.unseen), 32 - 8 - 2);
    expect(k.trump, -1, reason: 'seat 2 does not know the hidden trump');
    expect(know(state, 0).trump, Suit.hearts.index);
  });

  test('a declared Pair places the King and Queen of trump', () {
    final state = applyAll(
      dealHands({
        0: 'JS 9S JH 9H 7D 8D 7C 8C',
        1: 'KH QH AS 10S 9D 10D AC 10C',
        2: 'KS QS 8S 7S JD AD KD QD',
        3: 'AH 10H 8H 7H JC 9C KC QC',
      }),
      [
        const Bid(Seat(0), 16),
        const Pass(Seat(1)),
        const Pass(Seat(2)),
        const Pass(Seat(3)),
        const ChooseTrump(Seat(0), Suit.hearts),
        const NoDouble(Seat(1)),
        const NoDouble(Seat(3)),
        PlayCard(const Seat(0), Card.parse('7C')),
        PlayCard(const Seat(1), Card.parse('10C')),
        const AskTrump(Seat(2)),
        PlayCard(const Seat(2), Card.parse('7S')),
        PlayCard(const Seat(3), Card.parse('JC')),
        const DeclarePair(Seat(1)),
      ],
    );
    final k = know(state, 0);
    expect(k.placed[C29.index(Card.parse('KH'))], 1);
    expect(k.placed[C29.index(Card.parse('QH'))], 1);
  });

  test('a hidden seventh card is one more card out', () {
    var state = applyAll(dealHands(hands), const [
      Bid(Seat(0), 16),
      Pass(Seat(1)),
      Pass(Seat(2)),
      Pass(Seat(3)),
      CallSeventhCard(Seat(0)),
      NoDouble(Seat(1)),
      NoDouble(Seat(3)),
    ]);
    state = playCards(state, 'JS');
    final other = know(state, 1);
    expect(other.hiddenSeventh, isTrue);
    expect(other.ownSeventh, -1);
    final room = other.handSizes.fold(0, (a, b) => a + b) - other.handSizes[1];
    expect(C29.count(other.unseen), room + 1);
    final bidder = know(state, 0);
    expect(bidder.hiddenSeventh, isFalse);
    expect(bidder.ownSeventh, C29.index(state.seventhCard!));
  });

  test('sampled worlds respect everything the bot knows', () {
    final random = Xoshiro256StarStar.seeded(9);
    var worlds = 0;
    while (worlds < 2000) {
      final position = randomPosition(random);
      final state = position.state;
      if (state.phase != TwentyNinePhase.play) continue;
      final seat = position.seat.index;
      final k = know(state, seat);
      for (var i = 0; i < 20; i++) {
        final world = sampleWorld(k, random)!;
        worlds++;
        expect(world.hands[seat], k.hand);
        var dealt = world.seventh >= 0 && world.seventh != k.ownSeventh
            ? 1 << world.seventh
            : 0;
        for (var other = 0; other < 4; other++) {
          if (other == seat) continue;
          final hand = world.hands[other];
          expect(C29.count(hand), k.handSizes[other]);
          expect(dealt & hand, 0, reason: 'a card dealt twice');
          dealt |= hand;
          for (var suit = 0; suit < 4; suit++) {
            if (k.voidSuits[other] & (1 << suit) != 0) {
              expect(hand & C29.suitMask(suit), 0, reason: 'a void broken');
            }
          }
        }
        // Placed cards include a revealed seventh card: public, so not
        // unseen, but still in the bidder's hand.
        var placed = 0;
        for (final card in k.placed.keys) {
          placed |= 1 << card;
        }
        expect(
          dealt,
          k.unseen | placed,
          reason: 'every unseen card dealt once',
        );
        for (final MapEntry(key: card, value: holder) in k.placed.entries) {
          expect(C29.has(world.hands[holder], card), isTrue);
        }
        if (k.trump >= 0) expect(world.trump, k.trump);
        if (state.seventhCardSetAside && k.hiddenSeventh) {
          expect(world.trump, C29.suitOf(world.seventh));
        }
      }
    }
  });

  test('longestSuit picks the suit with most cards, then most points', () {
    final random = Xoshiro256StarStar.seeded(1);
    expect(longestSuit(C29.maskOf(cards('JH 9H 7S 8S 9S')), random), 0);
    expect(longestSuit(C29.maskOf(cards('JH 9H 7S 8S')), random), 1);
  });
}
