import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('the deck (AGENTS.md §6.1)', () {
    test('has 32 unique cards, 7 to A in each suit', () {
      final deck = TwentyNineRules.deck;
      expect(deck, hasLength(32));
      expect(deck.toSet(), hasLength(32));
      for (final suit in Suit.values) {
        expect(deck.where((c) => c.suit == suit).map((c) => c.rank.symbol), [
          '7',
          '8',
          '9',
          '10',
          'J',
          'Q',
          'K',
          'A',
        ]);
      }
    });

    test('is what the game definition reports', () {
      expect(const TwentyNineGame().deck, TwentyNineRules.deck);
      expect(const TwentyNineGame().id, 'twentynine');
      expect(const TwentyNineGame().rulesVersion, 1);
    });
  });

  group('card points', () {
    test('J 3, 9 2, A 1, 10 1, others 0', () {
      final expected = {
        Rank.jack: 3,
        Rank.nine: 2,
        Rank.ace: 1,
        Rank.ten: 1,
        Rank.king: 0,
        Rank.queen: 0,
        Rank.eight: 0,
        Rank.seven: 0,
      };
      for (final card in TwentyNineRules.deck) {
        expect(
          TwentyNineRules.points(card),
          expected[card.rank],
          reason: '$card',
        );
        expect(TwentyNineRules.isPointCard(card), expected[card.rank]! > 0);
      }
    });

    test('total 28 in the deck', () {
      expect(
        TwentyNineRules.deck
            .map(TwentyNineRules.points)
            .reduce((a, b) => a + b),
        28,
      );
    });
  });

  test('rank order in every suit is J, 9, A, 10, K, Q, 8, 7', () {
    final ranked = [...cards('7H 8H 9H 10H JH QH KH AH')]
      ..sort(
        (a, b) => TwentyNineRules.power(b.rank) - TwentyNineRules.power(a.rank),
      );
    expect(ranked.map((c) => c.id), [
      'JH',
      '9H',
      'AH',
      '10H',
      'KH',
      'QH',
      '8H',
      '7H',
    ]);
    expect(() => TwentyNineRules.power(Rank.two), throwsArgumentError);
  });

  group('seats and teams', () {
    test('teams are {0, 2} and {1, 3}', () {
      expect(
        [for (var i = 0; i < 4; i++) TwentyNineRules.teamOf(Seat(i))],
        [0, 1, 0, 1],
      );
      expect(TwentyNineRules.seatsOf(0), [const Seat(0), const Seat(2)]);
      expect(TwentyNineRules.seatsOf(1), [const Seat(1), const Seat(3)]);
    });

    test('partners sit opposite and play passes in seat order', () {
      expect(TwentyNineRules.partnerOf(const Seat(0)), const Seat(2));
      expect(TwentyNineRules.partnerOf(const Seat(3)), const Seat(1));
      expect(TwentyNineRules.next(const Seat(3)), const Seat(0));
      expect(TwentyNineRules.next(const Seat(1)), const Seat(2));
    });
  });
}
