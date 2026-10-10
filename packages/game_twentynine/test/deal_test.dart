import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Plays out the current deal with simple legal moves: everyone passes
/// (the dealer is forced to bid), the bidder names the first suit, nobody
/// doubles, and each player plays their first legal card. Somebody asks for
/// trump at the first chance, so the deal is scored.
void finishDeal(Table table) {
  final deal = table.state.dealNumber;
  while (!table.state.isOver && table.state.dealNumber == deal) {
    final legal = table.legal();
    final ask = legal.whereType<AskTrump>();
    final pass = legal.whereType<Pass>();
    final decline = legal.where(
      (a) =>
          a is NoDouble || a is NoRedouble || a is NoSingleHand || a is NoPair,
    );
    table.act(
      ask.isNotEmpty
          ? ask.first
          : pass.isNotEmpty
          ? pass.first
          : decline.isNotEmpty
          ? decline.first
          : legal.first,
    );
  }
}

void main() {
  group('the first dealer (AGENTS.md §6.3)', () {
    test('is random, drawn from the seed', () {
      final counts = List.filled(4, 0);
      for (var seed = 0; seed < 4000; seed++) {
        counts[Table.seeded(seed).state.dealer.index]++;
      }
      for (final count in counts) {
        expect(count, inInclusiveRange(850, 1150));
      }
    });

    test('is the same for the same seed', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(
          Table.seeded(seed).state.dealer,
          Table.seeded(seed).state.dealer,
        );
      }
    });
  });

  group('dealing', () {
    test('the same seed gives the same match, another seed another deal', () {
      final a = Table.seeded(42).state;
      final b = Table.seeded(42).state;
      final c = Table.seeded(43).state;
      expect(a.hash, b.hash);
      expect(a.hands, isNot(equals(c.hands)));
    });

    test('four cards each come first, starting after the dealer', () {
      final deck = stackedDeck(dealer: 1);
      final table = Table.deal(dealer: 1);
      final state = table.state;
      expect(state.firstPlayer, const Seat(2));
      expect(state.hands[2], deck.sublist(0, 4));
      expect(state.hands[3], deck.sublist(4, 8));
      expect(state.hands[0], deck.sublist(8, 12));
      expect(state.hands[1], deck.sublist(12, 16));
      expect(state.undealt, deck.sublist(16));
      expect(state.phase, TwentyNinePhase.auction);
      expect(state.turn, const Seat(2));
    });

    test('the second four complete eight cards each after doubling', () {
      final table = Table.deal(
        hands: {0: 'JS 9S AS 10S JH 9H 7D 8D', 1: 'KS QS 8S 7S AH 10H KH QH'},
      );
      expect(table.state.hands[0], cards('JS 9S AS 10S'));
      table.auction(0, 16);
      table.chooseTrump('C');
      expect(table.state.hands[0], hasLength(4));
      table.noDoubles();
      expect(table.state.hands[0], cards('JS 9S AS 10S JH 9H 7D 8D'));
      expect(table.state.hands[1], cards('KS QS 8S 7S AH 10H KH QH'));
      expect(table.state.hands.every((h) => h.length == 8), isTrue);
      expect(table.state.undealt, isEmpty);
      expect(table.state.phase, TwentyNinePhase.play);
    });

    test('each deal starts with an event that logs its seed', () {
      final table = Table.seeded(7);
      final started = table.eventsOf<DealStarted>().last;
      expect(started.seed, table.state.dealSeed);
      expect(started.dealNumber, 1);
      expect(started.dealer, table.state.dealer);
      expect(started.payload['seed'], seedToHex(table.state.dealSeed!));
      expect(started.deck, isNull);
    });

    test('a given deck is logged instead of a seed', () {
      final table = Table.deal(dealer: 0);
      final started = table.eventsOf<DealStarted>().single;
      expect(started.seed, isNull);
      expect(started.deck, stackedDeck(dealer: 0));
      expect(started.payload['deck'], hasLength(32));
    });

    test('initWithDeck rejects a bad deck or dealer', () {
      const game = TwentyNineGame();
      final config = testConfig.toMatchConfig();
      final deck = stackedDeck(dealer: 0);
      expect(
        () => game.initWithDeck(
          config,
          1,
          dealer: const Seat(0),
          deck: deck.sublist(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => game.initWithDeck(
          config,
          1,
          dealer: const Seat(0),
          deck: [...deck.sublist(1), deck[1]],
        ),
        throwsArgumentError,
      );
      expect(
        () => game.initWithDeck(config, 1, dealer: const Seat(4), deck: deck),
        throwsArgumentError,
      );
    });

    test('the deal passes to the next player after each deal', () {
      final table = Table.deal();
      finishDeal(table);
      expect(table.state.dealer, const Seat(0));
      expect(table.state.dealNumber, 2);
      expect(table.eventsOf<DealStarted>().last.dealNumber, 2);
      expect(table.eventsOf<DealStarted>().last.dealer, const Seat(0));
      finishDeal(table);
      expect(table.state.dealer, const Seat(1));
    });
  });

  group('redeal check A (AGENTS.md §6.7)', () {
    const checks = TwentyNineConfig();

    test('cancels when the first player has no point card', () {
      final table = Table.deal(config: checks, hands: {0: 'KS QS 8S 7S'});
      final cancelled = table.eventsOf<DealCancelled>();
      expect(cancelled.single.reason, DealCancelReason.firstPlayerNoPointCards);
      final started = table.eventsOf<DealStarted>();
      expect(started, hasLength(2));
      expect(started.last.dealer, const Seat(3));
      expect(started.last.dealNumber, 1);
      expect(started.last.seed, isNotNull);
      expect(table.state.dealer, const Seat(3));
      expect(table.state.phase, TwentyNinePhase.auction);
      expect(table.state.hands[0].any(TwentyNineRules.isPointCard), isTrue);
    });

    test('looks only at the first player', () {
      final table = Table.deal(
        config: checks,
        hands: {0: 'JS 8H 8D 8C', 1: 'KS QS 8S 7S'},
      );
      expect(table.eventsOf<DealCancelled>(), isEmpty);
    });

    test('is skipped when redeal checks are off', () {
      final table = Table.deal(hands: {0: 'KS QS 8S 7S'});
      expect(table.eventsOf<DealCancelled>(), isEmpty);
      expect(table.state.hands[0], cards('KS QS 8S 7S'));
    });
  });

  group('redeal check B', () {
    const checks = TwentyNineConfig();
    // Seat 0 is the first player and bids; seat 3 deals.
    Table dealt(Map<int, String> hands, {TwentyNineConfig config = checks}) {
      final table = Table.deal(config: config, hands: hands)
        ..auction(0, 16)
        ..chooseTrump('S')
        ..noDoubles();
      return table;
    }

    test('cancels when a player has no point card in eight', () {
      final table = dealt({
        0: 'JS 9S AS 10S JH 9H AH 10H',
        1: 'KS QS 8S 7S KH QH 8H 7H',
        2: 'JD 9D AD 10D KD QD 8D 7D',
        3: 'JC 9C AC 10C KC QC 8C 7C',
      });
      expect(
        table.eventsOf<DealCancelled>().single.reason,
        DealCancelReason.playerNoPointCards,
      );
      expect(table.state.phase, TwentyNinePhase.auction);
      expect(table.state.dealer, const Seat(3));
      expect(table.state.dealNumber, 1);
      expect(table.state.bidder, isNull);
    });

    test('cancels when one player holds all four Jacks', () {
      final jacks = dealt({
        0: 'JS JH JD JC 9S AS 10S 9H',
        1: 'KS QS 8S 7S AH 10H KH QH',
        2: '9D AD 10D KD 8H 7H QD 8D',
        3: '9C AC 10C KC QC 8C 7C 7D',
      });
      expect(
        jacks.eventsOf<DealCancelled>().single.reason,
        DealCancelReason.allFourJacks,
      );
    });

    test('cancels when one player holds eight cards of one suit', () {
      final table = dealt({
        0: 'JS 9S AS 10S JH 9H AH 10H',
        1: 'KS QS 8S 7S KH QH 8H JD',
        2: '7H 9D AD 10D KD QD 8D 7D',
        3: 'JC 9C AC 10C KC QC 8C 7C',
      });
      expect(
        table.eventsOf<DealCancelled>().single.reason,
        DealCancelReason.eightOfOneSuit,
      );
    });

    test('counts a set-aside seventh card as dealt to the bidder', () {
      // Seat 2 bids; its only point card is its seventh card, JD.
      final table = Table.deal(
        dealer: 0,
        config: checks,
        hands: {
          1: 'JS 9S KH QH 7D AH 7C 8C',
          2: 'KS QS 8S 7S 8H 7H JD QD',
          3: 'AS 10S 9H 10H 8D 9D JC 9C',
          0: 'JH 10D KD AD AC 10C KC QC',
        },
      )..auction(2, 16);
      table
        ..act(CallSeventhCard(table.bidder))
        ..noDoubles();
      expect(table.state.seventhCard, Card.parse('JD'));
      expect(table.eventsOf<DealCancelled>(), isEmpty);
      expect(table.state.phase, TwentyNinePhase.play);
    });

    test('is skipped when redeal checks are off', () {
      final table = dealt({
        0: 'JS 9S AS 10S JH 9H AH 10H',
        1: 'KS QS 8S 7S KH QH 8H 7H',
      }, config: testConfig);
      expect(table.eventsOf<DealCancelled>(), isEmpty);
      expect(table.state.phase, TwentyNinePhase.play);
    });
  });
}
