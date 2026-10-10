import 'package:card_games/data/event_log.dart';
import 'package:card_games/features/debug/card_gallery_screen.dart';
import 'package:card_games/shared/cards/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('starts in the lobby with Twenty-Nine listed', (tester) async {
    await tester.pumpWidget(testApp(MemoryEventLog()));
    await tester.pumpAndSettle();

    expect(find.text('card.games'), findsOneWidget);
    expect(find.text('Choose a game'), findsOneWidget);
    expect(find.text('Twenty-Nine'), findsOneWidget);
    expect(find.text('Against three computer players'), findsOneWidget);
  });

  testWidgets('debug builds open the card gallery from the lobby', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(MemoryEventLog()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Card assets'));
    await tester.pumpAndSettle();

    expect(find.byType(CardGalleryScreen), findsOneWidget);
    expect(find.byType(PlayingCard), findsWidgets);
  });
}
