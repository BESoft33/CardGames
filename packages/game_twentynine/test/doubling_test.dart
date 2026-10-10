import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Seat [bidder] wins at 16 and names clubs; doubling is next.
Table afterTrump(int bidder) => Table.deal()
  ..auction(bidder, 16)
  ..chooseTrump('C');

void main() {
  group('double and redouble (AGENTS.md §6.6)', () {
    test('the opponents decide in play order after the bidder', () {
      final table = afterTrump(1);
      expect(table.state.phase, TwentyNinePhase.doubling);
      expect(table.turn, const Seat(2));
      expect(table.legal(), const [Double(Seat(2)), NoDouble(Seat(2))]);
      expect(table.state.hands[0], hasLength(4), reason: 'before second deal');
      table.act(const NoDouble(Seat(2)));
      expect(table.turn, const Seat(0));
      table.act(const NoDouble(Seat(0)));
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.state.stake, 1);
      expect(table.state.hands[0], hasLength(8));
    });

    test('a double makes the stake 2 and ends the doubling', () {
      final table = afterTrump(0)..act(const Double(Seat(1)));
      expect(table.state.stake, 2);
      expect(table.state.doubledBy, const Seat(1));
      expect(table.state.phase, TwentyNinePhase.redoubling);
      expect(table.turn, const Seat(0), reason: 'seat 3 is not asked');
    });

    test('the bidder, then the partner, may redouble to 4', () {
      final table = afterTrump(0)
        ..actAll(const [Double(Seat(1)), NoRedouble(Seat(0))]);
      expect(table.turn, const Seat(2));
      expect(table.legal(), const [Redouble(Seat(2)), NoRedouble(Seat(2))]);
      table.act(const Redouble(Seat(2)));
      expect(table.state.stake, 4);
      expect(table.state.redoubledBy, const Seat(2));
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.eventsOf<ActionTaken>().map((e) => e.name).skip(5), [
        'doubled',
        'redoubleDeclined',
        'redoubled',
      ]);
    });

    test('the second opponent may double after the first declines', () {
      final table = afterTrump(0)
        ..actAll(const [NoDouble(Seat(1)), Double(Seat(3))]);
      expect(table.state.doubledBy, const Seat(3));
      expect(table.turn, const Seat(0));
      table.act(const Redouble(Seat(0)));
      expect(table.state.stake, 4);
      expect(
        table.state.phase,
        TwentyNinePhase.play,
        reason: 'partner not asked',
      );
    });

    test('if neither redoubles the stake stays 2', () {
      final table = afterTrump(0)
        ..actAll(const [
          Double(Seat(1)),
          NoRedouble(Seat(0)),
          NoRedouble(Seat(2)),
        ]);
      expect(table.state.stake, 2);
      expect(table.state.redoubledBy, isNull);
      expect(table.state.phase, TwentyNinePhase.play);
    });

    test('everyone sees the doubling', () {
      final table = afterTrump(0)
        ..actAll(const [Double(Seat(1)), Redouble(Seat(0))]);
      for (final seat in [0, 1, 2, 3]) {
        final view = table.view(seat);
        expect(view.doubledBy, const Seat(1));
        expect(view.redoubledBy, const Seat(0));
        expect(view.stake, 4);
      }
    });

    test('with the option off, the second deal follows trump at once', () {
      final table =
          Table.deal(config: testConfig.copyWith(doubleRedouble: false))
            ..auction(0, 16)
            ..chooseTrump('C');
      expect(table.state.phase, TwentyNinePhase.play);
      expect(table.state.hands.every((h) => h.length == 8), isTrue);
      expect(table.state.stake, 1);
    });
  });
}
