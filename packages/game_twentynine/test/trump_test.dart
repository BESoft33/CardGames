import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat 1 leads hearts; seat 2 bids and its only heart is its seventh card.
Table seventhCardDeal({TwentyNineConfig config = testConfig}) {
  final table = Table.deal(
    dealer: 0,
    config: config,
    hands: {
      1: 'AH 10H KH QH 7S 8S 7C 8C',
      2: 'JS 9S AS 10S JD 9D JH 9C',
      3: '8H 7H 9H QS KS 10D AD KD',
      0: 'JC AC 10C KC QC QD 8D 7D',
    },
  )..auction(2, 16);
  table.act(CallSeventhCard(table.bidder));
  if (config.doubleRedouble) table.noDoubles();
  return table;
}

void main() {
  group('naming trump (AGENTS.md §6.5)', () {
    test('the bidder may name any suit or call seventh card', () {
      final table = Table.deal()..auction(0, 16);
      expect(table.legal(), [
        for (final suit in Suit.values) ChooseTrump(const Seat(0), suit),
        const CallSeventhCard(Seat(0)),
      ]);
    });

    test('seventh card is not offered when the option is off', () {
      final table = Table.deal(config: testConfig.copyWith(seventhCard: false))
        ..auction(0, 16);
      expect(table.legal().whereType<CallSeventhCard>(), isEmpty);
      expect(table.legal(), hasLength(4));
    });

    test('the suit is secret: only the bidder sees it', () {
      final table = Table.deal()
        ..auction(0, 16)
        ..chooseTrump('H');
      expect(table.state.trumpSuit, Suit.hearts);
      expect(table.view(0).trumpSuit, Suit.hearts);
      for (final seat in [1, 2, 3]) {
        expect(table.view(seat).trumpSuit, isNull, reason: 'seat $seat');
        expect(table.view(seat).trumpMode, TrumpMode.suit);
        expect(table.view(seat).trumpRevealed, isFalse);
      }
    });
  });

  group('seventh card', () {
    test('nobody knows it before the second deal, not even the bidder', () {
      final table = Table.deal()..auction(0, 16);
      table.act(CallSeventhCard(table.bidder));
      expect(table.state.phase, TwentyNinePhase.doubling);
      for (final seat in [0, 1, 2, 3]) {
        expect(table.view(seat).trumpMode, TrumpMode.seventhCard);
        expect(table.view(seat).seventhCard, isNull);
        expect(table.view(seat).trumpSuit, isNull);
      }
    });

    test('the seventh card dealt is set aside and its suit is trump', () {
      final table = seventhCardDeal();
      expect(table.state.seventhCard, Card.parse('JH'));
      expect(table.state.seventhCardSetAside, isTrue);
      expect(table.state.trumpSuit, Suit.hearts);
      expect(table.state.hands[2], cards('JS 9S AS 10S JD 9D 9C'));
      expect(table.view(2).seventhCard, Card.parse('JH'));
      expect(table.view(2).trumpSuit, Suit.hearts);
      expect(table.view(2).handSizes, [8, 8, 7, 8]);
      for (final seat in [0, 1, 3]) {
        expect(table.view(seat).seventhCard, isNull);
        expect(table.view(seat).trumpSuit, isNull);
        expect(table.view(seat).seventhCardSetAside, isTrue);
      }
    });

    test('it does not count for following suit', () {
      final table = seventhCardDeal()..play('AH');
      expect(table.turn, const Seat(2));
      expect(table.playable(), 'JS 9S AS 10S JD 9D 9C');
      expect(table.legal().last, const AskTrump(Seat(2)));
    });

    test('it cannot be led while the bidder has other cards', () {
      // Seat 2 wins the spade trick without revealing, so it leads next.
      final table = seventhCardDeal()..play('7S JS QS 7D');
      expect(table.state.trumpRevealed, isFalse);
      expect(table.turn, const Seat(2));
      expect(table.playable(), '9S AS 10S JD 9D 9C');
      expect(table.legal().whereType<AskTrump>(), isEmpty);
    });

    test('revealing shows it to everyone and it joins the hand', () {
      final table = seventhCardDeal()
        ..play('AH')
        ..act(const AskTrump(Seat(2)));
      final revealed = table.eventsOf<TrumpRevealed>().single;
      expect(revealed.revealedBy, const Seat(2));
      expect(revealed.suit, Suit.hearts);
      expect(revealed.seventhCard, Card.parse('JH'));
      expect(revealed.payload, {'suit': 'H', 'seventhCard': 'JH'});
      expect(table.state.seventhCardSetAside, isFalse);
      expect(table.state.hands[2], contains(Card.parse('JH')));
      for (final seat in [0, 1, 2, 3]) {
        expect(table.view(seat).seventhCard, Card.parse('JH'));
        expect(table.view(seat).trumpSuit, Suit.hearts);
      }
      // Having asked, the bidder must play a trump: the seventh card.
      expect(table.playable(), 'JH');
    });

    test('a reveal by another player also puts it in the bidder\'s hand', () {
      // Seat 1 leads clubs; seat 2 discards; seat 3 has no clubs and asks.
      final table = seventhCardDeal()
        ..play('7C 9C')
        ..act(const AskTrump(Seat(3)));
      expect(table.eventsOf<TrumpRevealed>().single.revealedBy, const Seat(3));
      expect(table.state.hands[2].last, Card.parse('JH'));
      expect(table.playable(), '8H 7H 9H');
    });

    test('playing it as the last card reveals trump', () {
      final table = Table.deal()..auction(0, 16);
      table
        ..act(CallSeventhCard(table.bidder))
        ..noDoubles();
      final seventh = table.state.seventhCard!;
      // Nobody asks, so the seventh card stays hidden until trick 8.
      while (table.state.tricks.length < 7) {
        final legal = table.legal();
        table.act(legal.firstWhere((a) => a is PlayCard || a is NoPair));
      }
      expect(table.state.trumpRevealed, isFalse);
      while (table.turn != const Seat(0)) {
        table.act(table.legal().firstWhere((a) => a is PlayCard));
      }
      expect(table.legal(), [PlayCard(const Seat(0), seventh)]);
      table.act(PlayCard(const Seat(0), seventh));
      final revealed = table.eventsOf<TrumpRevealed>().single;
      expect(revealed.revealedBy, const Seat(0));
      expect(revealed.seventhCard, seventh);
      while (table.state.dealNumber == 1) {
        table.act(table.legal().first);
      }
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.outcome, isNot(DealOutcome.voided));
    });
  });
}
