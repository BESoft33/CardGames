import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat 3 deals, so seat 0 leads the first trick. Seat 0 bids 16.
const Map<int, String> handsP = {
  0: 'JS 9S AS 10S JH 9H 7D 8D',
  1: 'KS QS 8S 7S AH 10H KH QH',
  2: 'JD 9D AD 10D 8H 7H KD QD',
  3: 'JC 9C AC 10C KC QC 8C 7C',
};

/// Seat 0 deals and is forced to bid; seat 1 leads clubs, which the bidder
/// does not hold. Trump is diamonds.
const Map<int, String> handsB = {
  0: 'JS 9S AS 10S JD 9D KH QH',
  1: 'JC 9C AC 10C KS QS 8S 7S',
  2: 'JH 9H AH 10H 8H 7H AD 10D',
  3: 'KC QC 8C 7C KD QD 8D 7D',
};

Table tableP(String trump, {TwentyNineConfig config = testConfig}) =>
    Table.deal(hands: handsP, config: config)..startPlay(suit: trump);

Table tableB({TwentyNineConfig config = testConfig}) =>
    Table.deal(dealer: 0, hands: handsB, config: config)..startPlay(suit: 'D');

void main() {
  group('leading and following (AGENTS.md §6.9)', () {
    test('the first player leads the first trick, with any card', () {
      final table = tableP('C');
      expect(table.turn, const Seat(0));
      expect(table.playable(), 'JS 9S AS 10S JH 9H 7D 8D');
      expect(table.legal().whereType<AskTrump>(), isEmpty);
    });

    test('players must follow suit if they can', () {
      final table = tableP('C')..play('JS');
      expect(table.playable(), 'KS QS 8S 7S');
      expect(table.legal().whereType<AskTrump>(), isEmpty);
      expect(() => table.play('AH'), throwsA(isA<IllegalActionException>()));
    });

    test('a card not in hand is refused', () {
      final table = tableP('C');
      expect(
        () => table.act(PlayCard(const Seat(0), Card.parse('JC'))),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('the winner leads the next trick; trick points go to the team', () {
      final table = tableP('C')..play('JS 7S 8H 7C');
      final won = table.eventsOf<TrickWon>().single;
      expect(won.winner, const Seat(0));
      expect(won.trickNumber, 1);
      expect(won.points, 3);
      expect(table.state.cardPoints, [3, 0]);
      expect(table.turn, const Seat(0));
      expect(table.state.tricks.single.plays, hasLength(4));
      table.play('AS KS 7H 8C');
      expect(table.state.cardPoints, [4, 0]);
      expect(table.turn, const Seat(0));
    });
  });

  group('cannot follow while trump is hidden', () {
    test('may play any card or ask for trump', () {
      final table = tableP('C')..play('JS 7S');
      expect(table.playable(), 'JD 9D AD 10D 8H 7H KD QD');
      expect(table.legal().last, const AskTrump(Seat(2)));
    });

    test('a trump-suit discard without asking has no power', () {
      // Clubs are trump but hidden; seat 3's 7C does not beat JS.
      final table = tableP('C')..play('JS 7S 8H 7C');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(0));
      expect(table.state.trumpRevealed, isFalse);
    });

    test('asking reveals trump to all; the asker must then trump', () {
      final table = tableP('H')..play('JS 7S');
      table.ask();
      final revealed = table.eventsOf<TrumpRevealed>().single;
      expect(revealed.revealedBy, const Seat(2));
      expect(revealed.suit, Suit.hearts);
      expect(revealed.seventhCard, isNull);
      expect(table.state.trumpRevealed, isTrue);
      expect(table.state.revealTrick, 0);
      expect(table.state.revealedBy, const Seat(2));
      expect(table.view(1).revealedBy, const Seat(2));
      for (final seat in [0, 1, 2, 3]) {
        expect(table.view(seat).trumpSuit, Suit.hearts);
      }
      expect(table.turn, const Seat(2));
      expect(table.playable(), '8H 7H');
      expect(table.state.mustTrump, const Seat(2));
    });

    test('an asker without trumps may play any card', () {
      // Seat 3 holds only clubs; trump is hearts.
      final table = tableP('H')..play('JS 7S 8H');
      table.ask();
      expect(table.playable(), 'JC 9C AC 10C KC QC 8C 7C');
    });

    test('the highest trump wins the trick in which trump is revealed', () {
      final table = tableP('H')
        ..play('JS 7S')
        ..ask()
        ..play('7H 7C');
      final won = table.eventsOf<TrickWon>().single;
      expect(won.winner, const Seat(2), reason: '7H is the only trump');
      expect(won.points, 3);
      expect(table.state.cardPoints, [3, 0]);
    });

    test('a trump-suit card played before the reveal is a plain card, '
        'even in the trick in which trump is revealed', () {
      // Seat 1 discards QH without asking; seat 3 then asks, but holds no
      // trump: hearts are trump, yet QH went down before the reveal, so
      // the highest diamond, JD, wins.
      final table = tableP('H')..play('7D QH JD');
      table
        ..ask()
        ..play('7C');
      expect(table.state.trumpRevealed, isTrue);
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(2));
      expect(table.state.cardPoints, [3, 0]);
    });

    test('before the reveal the highest card of the suit led wins', () {
      final table = tableP('H')..play('7D KH JD 8C');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(2));
      expect(table.state.trumpRevealed, isFalse);
    });

    test('the bidder may lead the trump suit like any other suit', () {
      final table = tableP('H')..play('9H');
      expect(table.playable(), 'AH 10H KH QH');
      table.play('AH 8H 7C');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(0));
      expect(table.state.trumpRevealed, isFalse);
    });

    test('the bidder has the same choice: discard or reveal', () {
      final table = tableB()..play('JC 7H 7C');
      expect(table.turn, const Seat(0));
      expect(table.playable(), 'JS 9S AS 10S JD 9D KH QH');
      expect(table.legal().last, const AskTrump(Seat(0)));
      table.ask();
      expect(table.eventsOf<TrumpRevealed>().single.revealedBy, const Seat(0));
      expect(table.playable(), 'JD 9D');
      table.play('9D');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(0));
    });
  });

  group('after trump is revealed', () {
    Table revealed() => tableB()
      ..play('JC 7H 7C')
      ..ask()
      ..play('9D');

    test('nobody may ask again, and there is no duty to trump', () {
      final table = revealed()..play('JS KS');
      expect(table.turn, const Seat(2));
      expect(table.legal().whereType<AskTrump>(), isEmpty);
      expect(table.playable(), 'JH 9H AH 10H 8H AD 10D');
      table.play('8H');
      expect(table.playable(), 'KC QC 8C KD QD 8D 7D');
    });

    test('with no trump in the trick, the highest of the suit led wins', () {
      final table = revealed()..play('JS KS 8H 8C');
      expect(table.eventsOf<TrickWon>().last.winner, const Seat(0));
    });

    test('the highest trump wins', () {
      final table = revealed()..play('JS KS 10D KD');
      final won = table.eventsOf<TrickWon>().last;
      expect(won.winner, const Seat(2));
      expect(won.points, 4);
    });
  });

  group('with the mandatory ask option', () {
    const mandatory = TwentyNineConfig(
      redealChecks: false,
      askTrump: AskTrumpRule.mandatory,
    );

    test('a player who cannot follow must ask, then may play any card', () {
      final table = tableP('H', config: mandatory)..play('JS 7S');
      expect(table.legal(), const [AskTrump(Seat(2))]);
      table.ask();
      expect(table.playable(), 'JD 9D AD 10D 8H 7H KD QD');
      expect(table.state.mustTrump, isNull);
    });

    test('the bidder must reveal too', () {
      // As deal B, but seats 2 and 3 can follow clubs and the bidder cannot.
      final table = Table.deal(
        dealer: 0,
        config: mandatory,
        hands: {
          0: 'JS 9S AS 10S JD 9D KH QH',
          1: 'JC 9C AC 10C KS QS 8S 7S',
          2: 'JH 9H AH 10H 8H 7C AD 10D',
          3: 'KC QC 8C 7H KD QD 8D 7D',
        },
      )..startPlay(suit: 'D');
      table.play('JC 7C 8C');
      expect(table.legal(), const [AskTrump(Seat(0))]);
      table.ask();
      expect(table.playable(), 'JS 9S AS 10S JD 9D KH QH');
    });
  });

  test('if trump is never revealed the deal is void', () {
    final table = tableP('C');
    while (table.state.dealNumber == 1) {
      table.act(table.legal().firstWhere((a) => a is PlayCard));
    }
    final scored = table.eventsOf<DealScored>().single;
    expect(scored.outcome, DealOutcome.voided);
    expect(scored.delta, 0);
    expect(scored.scores, [0, 0]);
    expect(scored.teamPoints.reduce((a, b) => a + b), 29);
    expect(table.state.scores, [0, 0]);
    expect(table.eventsOf<TrickWon>(), hasLength(8));
  });

  // The owner's story (2026-10-10): Left leads; the Player, who bid and
  // named hearts, has no spade. Seats: Player 0, Right 1, Partner 2, Left 3,
  // so play goes Left, Player, Right, Partner. A trump-suit card has trump
  // power only if played once trump is revealed (AGENTS.md §6.9).
  group('the trump reveal story (AGENTS.md §6.9)', () {
    /// Right holds a spade.
    Table rightFollows() => Table.deal(
      dealer: 2,
      hands: const {
        0: 'AH 10H 9C 7C 8C 10C JC QC',
        1: 'QS JH 9H 8H JD QD KD AC',
        2: 'JS 9S 7H 8S 7S KH QH KC',
        3: 'AS 10S KS 7D 8D 9D 10D AD',
      },
    )..startPlay(suit: 'H');

    /// Right has no spade either; it holds the highest and lowest hearts.
    Table rightVoid() => Table.deal(
      dealer: 2,
      hands: const {
        0: 'AH 10H 9C 7C 8C 10C JC QC',
        1: 'JH 9H 7H 8H JD QD KD AC',
        2: 'JS 9S QS 8S 7S KH QH KC',
        3: 'AS 10S KS 7D 8D 9D 10D AD',
      },
    )..startPlay(suit: 'H');

    test('case 1: a trump played without a reveal is a discard', () {
      final table = rightFollows();
      expect(table.turn, const Seat(3), reason: 'Left leads');
      table.play('KS AH QS 7S');
      expect(table.state.trumpRevealed, isFalse);
      expect(
        table.eventsOf<TrickWon>().single.winner,
        const Seat(3),
        reason: 'the highest spade, KS, wins',
      );
    });

    test('case 2: a trump played before the reveal does not count, even in '
        'the trick in which it is revealed', () {
      final table = rightVoid()..play('KS AH');
      table
        ..ask()
        ..play('7H 7S');
      expect(table.state.trumpRevealed, isTrue);
      expect(table.state.revealedBy, const Seat(1));
      expect(
        table.eventsOf<TrickWon>().single.winner,
        const Seat(1),
        reason:
            "Right's 7H is the only trump; the Player's AH went down "
            'before the reveal',
      );
    });

    test('case 3: after the Player reveals, a higher trump wins', () {
      final table = rightVoid()..play('KS');
      table.ask();
      expect(table.playable(), 'AH 10H', reason: 'the asker must trump');
      table.play('10H');
      expect(
        table.playable(),
        'JH 9H 7H 8H JD QD KD AC',
        reason: 'no duty to trump once trump is revealed',
      );
      table.play('JH 7S');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(1));
    });

    test('case 4: after the Player reveals, a lower trump loses', () {
      final table = rightVoid()..play('KS');
      table
        ..ask()
        ..play('AH 7H 7S');
      expect(table.eventsOf<TrickWon>().single.winner, const Seat(0));
    });

    test('Right may only trump, high or low, when it holds no spade', () {
      final table = rightFollows()..play('KS');
      table
        ..ask()
        ..play('AH');
      expect(table.playable(), 'QS', reason: 'Right must follow suit');
    });
  });

  // The owner's report (2026-10-10): Right led 8D, Left revealed trump but
  // played no trump, the Player trumped, and Right won. Seat 0 deals, so
  // Right (seat 1) leads, then Partner, Left, Player.
  group("the owner's report: a trump played after the reveal wins", () {
    Table deal() => Table.deal(
      dealer: 0,
      hands: const {
        1: '8D AD 10D KD AC 10C KC QC',
        2: '7D QD 9D JD 8C 7C JC 9C',
        3: 'JH 9H AH 10H KH QH 8H 7H',
        0: 'JS 9S AS 10S KS QS 8S 7S',
      },
    )..startPlay(suit: 'S');

    test('the Player, bidding spades, trumps after Left reveals', () {
      final table = deal();
      expect(table.bidder, const Seat(0));
      expect(table.turn, const Seat(1), reason: 'Right leads');
      table.play('8D 7D');
      table.ask();
      expect(table.state.revealedBy, const Seat(3));
      table.play('7H');
      expect(table.playable(), contains('7S'));
      table.play('7S');
      expect(
        table.eventsOf<TrickWon>().single.winner,
        const Seat(0),
        reason: "the Player's 7S is the only trump, played after the reveal",
      );
      expect(table.view(0).tricks.single.winner, const Seat(0));
    });
  });
}
