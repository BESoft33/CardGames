import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  group('Suit', () {
    test('letters are S H D C in that order', () {
      expect(Suit.values.map((s) => s.letter), ['S', 'H', 'D', 'C']);
    });

    test('hearts and diamonds are red', () {
      expect(Suit.values.where((s) => s.isRed), [Suit.hearts, Suit.diamonds]);
    });

    test('tryParse accepts only exact letters', () {
      expect(Suit.tryParse('H'), Suit.hearts);
      expect(Suit.tryParse('h'), isNull);
      expect(Suit.tryParse('X'), isNull);
      expect(Suit.tryParse(''), isNull);
    });
  });

  group('Rank', () {
    test('symbols run from 2 to A', () {
      expect(Rank.values.map((r) => r.symbol), [
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        'J',
        'Q',
        'K',
        'A',
      ]);
    });

    test('tryParse accepts only exact symbols', () {
      expect(Rank.tryParse('10'), Rank.ten);
      expect(Rank.tryParse('T'), isNull);
      expect(Rank.tryParse('j'), isNull);
    });
  });

  group('Card', () {
    test('there are 52 cards with unique IDs, indexed 0 to 51', () {
      expect(Card.values, hasLength(52));
      expect(Card.values.map((c) => c.id).toSet(), hasLength(52));
      for (var i = 0; i < Card.values.length; i++) {
        expect(Card.values[i].index, i);
      }
    });

    test('IDs are rank symbol then suit letter', () {
      expect(Card(Rank.jack, Suit.hearts).id, 'JH');
      expect(Card(Rank.ten, Suit.spades).id, '10S');
      expect(Card(Rank.seven, Suit.clubs).id, '7C');
      expect(Card(Rank.ace, Suit.diamonds).toString(), 'AD');
    });

    test('parse round-trips every card and returns the shared instance', () {
      for (final card in Card.values) {
        expect(identical(Card.parse(card.id), card), isTrue);
        expect(identical(Card(card.rank, card.suit), card), isTrue);
      }
    });

    test('parse rejects anything that is not exactly a card ID', () {
      for (final bad in ['', 'J', '10', 'jh', 'JX', '1S', '11H', 'TS', ' JH']) {
        expect(Card.tryParse(bad), isNull, reason: bad);
        expect(() => Card.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('equality and hashCode follow the index', () {
      final a = Card.parse('QS');
      expect(a, Card(Rank.queen, Suit.spades));
      expect(a.hashCode, a.index);
      expect(a == Card.parse('QH'), isFalse);
      expect(<Card>{a, Card.parse('QS')}, hasLength(1));
    });

    test('compareTo orders by suit, then rank', () {
      final sorted = [
        Card.parse('2C'),
        Card.parse('AS'),
        Card.parse('2S'),
        Card.parse('KH'),
      ]..sort();
      expect(sorted.map((c) => c.id), ['2S', 'AS', 'KH', '2C']);
    });
  });
}
