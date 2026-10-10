import 'package:card_games/features/games/twentynine/table_layout.dart';
import 'package:card_games/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twentynine/game_twentynine.dart';

void main() {
  group('seating on screen (AGENTS.md §5.10)', () {
    const me = Seat(1);

    test('counter-clockwise: the next player is on the right', () {
      const direction = PlayDirection.counterClockwise;
      expect(sideOf(me, me: me, direction: direction), ScreenSide.bottom);
      expect(
        sideOf(const Seat(2), me: me, direction: direction),
        ScreenSide.right,
      );
      expect(
        sideOf(const Seat(3), me: me, direction: direction),
        ScreenSide.top,
      );
      expect(
        sideOf(const Seat(0), me: me, direction: direction),
        ScreenSide.left,
      );
    });

    test('clockwise: the next player is on the left', () {
      const direction = PlayDirection.clockwise;
      expect(
        sideOf(const Seat(2), me: me, direction: direction),
        ScreenSide.left,
      );
      expect(
        sideOf(const Seat(3), me: me, direction: direction),
        ScreenSide.top,
      );
      expect(
        sideOf(const Seat(0), me: me, direction: direction),
        ScreenSide.right,
      );
    });

    test('the partner is always at the top', () {
      for (var seat = 0; seat < 4; seat++) {
        for (final direction in PlayDirection.values) {
          expect(
            sideOf(
              TwentyNineRules.partnerOf(Seat(seat)),
              me: Seat(seat),
              direction: direction,
            ),
            ScreenSide.top,
          );
        }
      }
    });

    test('seats are named from the player\'s point of view', () {
      final l10n = AppLocalizationsEn();
      const direction = PlayDirection.counterClockwise;
      expect(seatName(l10n, me, me: me, direction: direction), 'You');
      expect(
        seatName(l10n, const Seat(3), me: me, direction: direction),
        'Partner',
      );
      expect(
        seatName(l10n, const Seat(2), me: me, direction: direction),
        'Right',
      );
      expect(
        seatName(l10n, const Seat(0), me: me, direction: direction),
        'Left',
      );
    });
  });

  test('the hand alternates suit colours, strongest first', () {
    final hand = [
      for (final id in ['7H', 'JS', '10D', 'JH', '9S', 'AC', 'QH', '8D'])
        Card.parse(id),
    ];
    expect(sortedHand(hand).map((c) => c.id), [
      'JS',
      '9S',
      'JH',
      'QH',
      '7H',
      'AC',
      '10D',
      '8D',
    ]);
  });
}
