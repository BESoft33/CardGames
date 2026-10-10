import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat 3 deals; seat 0 bids. Seat 1 holds the top spades and hearts.
const Map<int, String> handsSingle = {
  0: 'KS QS 8S 7S KH QH 8H 7H',
  1: 'JS 9S AS 10S JH 9H AH 10H',
  2: 'JD 9D AD 10D KD QD 8D 7D',
  3: 'JC 9C AC 10C KC QC 8C 7C',
};

final TwentyNineConfig singleConfig = testConfig.copyWith(singleHand: true);

void main() {
  group('single hand (AGENTS.md §6.8)', () {
    test('is off by default', () {
      final table = Table.deal(hands: handsSingle)..startPlay();
      expect(table.state.phase, TwentyNinePhase.play);
    });

    test('after the second deal each player in turn may declare', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..startPlay();
      expect(table.state.phase, TwentyNinePhase.singleHand);
      expect(table.state.hands.every((h) => h.length == 8), isTrue);
      expect(table.turn, const Seat(0));
      expect(table.legal(), const [
        DeclareSingleHand(Seat(0)),
        NoSingleHand(Seat(0)),
      ]);
    });

    test('priority runs in play order; later players are not asked', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..startPlay()
        ..actAll(const [NoSingleHand(Seat(0)), DeclareSingleHand(Seat(1))]);
      expect(table.state.singleHandDeclarer, const Seat(1));
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.turn, const Seat(1), reason: 'the declarer leads');
      expect(table.eventsOf<ActionTaken>().map((e) => e.name).skip(7), [
        'singleHandDeclined',
        'singleHandDeclared',
      ]);
    });

    test('if nobody declares, the first player leads as usual', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..startPlay()
        ..actAll(const [
          NoSingleHand(Seat(0)),
          NoSingleHand(Seat(1)),
          NoSingleHand(Seat(2)),
          NoSingleHand(Seat(3)),
        ]);
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.state.singleHandDeclarer, isNull);
      expect(table.turn, const Seat(0));
      expect(table.state.stake, 1);
    });

    test('no trump, doubles void, partner skipped, three-card tricks, +3', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..auction(0, 16)
        ..chooseTrump('C')
        ..actAll(const [
          Double(Seat(1)),
          NoRedouble(Seat(0)),
          NoRedouble(Seat(2)),
          NoSingleHand(Seat(0)),
          DeclareSingleHand(Seat(1)),
        ]);
      expect(table.state.stake, 3);
      table.play('JS');
      expect(table.turn, const Seat(2));
      expect(table.legal().whereType<AskTrump>(), isEmpty);
      table.play('7D');
      expect(table.turn, const Seat(0), reason: 'seat 3 is skipped');
      table.play('7S');
      expect(table.state.tricks.single.plays, hasLength(3));
      expect(table.state.tricks.single.winner, const Seat(1));
      for (final lead in cards('9S AS 10S JH 9H AH 10H')) {
        table.act(PlayCard(const Seat(1), lead));
        while (table.state.trick.isNotEmpty) {
          expect(table.state.phase, TwentyNinePhase.play, reason: 'no Pair');
          table.act(table.legal().first);
        }
      }
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.outcome, DealOutcome.singleHandWon);
      expect(scored.team, 1);
      expect(scored.delta, 3);
      expect(scored.stake, 3);
      expect(scored.target, isNull);
      expect(table.state.scores, [0, 3]);
      expect(table.eventsOf<TrumpRevealed>(), isEmpty);
      expect(table.state.dealNumber, 2);
    });

    test('the deal ends as soon as the declarer loses a trick, -3', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..startPlay()
        ..act(const DeclareSingleHand(Seat(0)));
      // Seat 2 is the declarer's partner and is skipped.
      table.play('KS JS');
      expect(table.turn, const Seat(3));
      table.play('7C');
      final scored = table.eventsOf<DealScored>().single;
      expect(scored.outcome, DealOutcome.singleHandLost);
      expect(scored.team, 0);
      expect(scored.delta, -3);
      expect(table.state.scores, [-3, 0]);
      expect(table.eventsOf<TrickWon>(), hasLength(1));
      expect(table.state.dealNumber, 2);
      expect(table.state.dealer, const Seat(0));
      expect(
        table.eventsOf<ActionTaken>().where(
          (e) => e.name == 'singleHandDeclined',
        ),
        isEmpty,
      );
    });

    test('a set-aside seventh card goes back to the bidder', () {
      final table = Table.deal(hands: handsSingle, config: singleConfig)
        ..auction(0, 16);
      table
        ..act(const CallSeventhCard(Seat(0)))
        ..noDoubles();
      expect(table.state.seventhCardSetAside, isTrue);
      expect(table.state.hands[0], hasLength(7));
      table.actAll(const [NoSingleHand(Seat(0)), DeclareSingleHand(Seat(1))]);
      expect(table.state.seventhCardSetAside, isFalse);
      expect(table.state.hands[0], hasLength(8));
      expect(table.state.hands[0].last, Card.parse('8H'));
      expect(table.view(1).seventhCard, isNull, reason: 'still secret');
      expect(table.view(0).seventhCard, Card.parse('8H'));
    });
  });
}
