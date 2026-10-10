import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/features/games/twentynine/offline_match.dart';
import 'package:card_games/features/games/twentynine/setup_screen.dart';
import 'package:card_games/features/games/twentynine/table_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/test_app.dart';

/// The app with an in-memory log and instant in-process bots.
Widget app(EventLog log) => testApp(log);

/// The key of the control that takes [action] on screen.
String keyOf(TwentyNineAction action) => switch (action) {
  // The player only bids here when the dealer must: the minimum, +1.
  Bid() => 'bid-plus-1',
  MatchBid() => 'bid-match',
  Pass() => 'pass',
  ChooseTrump(:final suit) => 'trump-${suit.letter}',
  CallSeventhCard() => 'seventh-card',
  Double() => 'double',
  NoDouble() => 'no-double',
  Redouble() => 'redouble',
  NoRedouble() => 'no-redouble',
  DeclareSingleHand() => 'single-hand',
  NoSingleHand() => 'no-single-hand',
  PlayCard(:final card) => 'hand-${card.id}',
  AskTrump() => 'ask-trump',
  DeclarePair() => 'declare-pair',
  NoPair() => 'no-pair',
};

/// Scrolls the setup list until the control with [key] is on screen.
Future<void> reveal(WidgetTester tester, String key) =>
    revealFound(tester, find.byKey(ValueKey(key)));

/// Scrolls the setup list until [finder] is on screen.
Future<void> revealFound(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // The list jumps to the control; lay it out there before tapping.
  await tester.pump();
}

Future<void> openSetup(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-twentynine')));
  await tester.pumpAndSettle();
  expect(find.byType(TwentyNineSetupScreen), findsOneWidget);
}

Future<void> startMatch(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('start-match')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(TwentyNineTableScreen), findsOneWidget);
}

/// Plays the player's turns by tapping the on-screen controls, choosing the
/// first legal action other than doubling, until [done].
Future<void> playUntil(WidgetTester tester, bool Function() done) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TwentyNineTableScreen)),
  );
  for (var step = 0; step < 400 && !done(); step++) {
    await tester.pump();
    final table = container.read(offlineMatchProvider);
    if (table == null || done()) break;
    final view = table.view;
    if (!view.isMyTurn || table.dealResult != null) continue;
    final choices = view.legalActions;
    final action = choices.firstWhere(
      (a) => a is Pass || a is NoDouble || a is NoRedouble || a is NoSingleHand,
      orElse: () => choices.first,
    );
    final control = find.byKey(ValueKey(keyOf(action)));
    await tester.ensureVisible(control);
    await tester.pump();
    if (action is PlayCard) {
      // Cards in the hand overlap: tap the strip of the card left in sight,
      // as a player would.
      await tester.tapAt(tester.getTopLeft(control) + const Offset(10, 30));
    } else {
      await tester.tap(control);
    }
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'the expected point of play was not reached');
}

/// Screens in physical pixels and pixel ratio: a tall phone of 393 × 873
/// points, a small one of 360 × 640 points, and a window of 360 × 400
/// points, such as a phone in split screen, where the table scrolls.
const List<(String, Size, double)> screens = [
  ('a tall phone', Size(1080, 2400), 2.75),
  ('a small phone', Size(720, 1280), 2.0),
  ('a short window', Size(720, 800), 2.0),
];

/// Shows the app on a screen of [size] physical pixels at [ratio].
void useScreen(WidgetTester tester, Size size, double ratio) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

void main() {
  // A tap that would miss its control fails the test instead of warning.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final (screen, size, ratio) in screens) {
    testWidgets(
      'the lobby leads to a match set up with the player\'s rules on $screen',
      (tester) async {
        useScreen(tester, size, ratio);
        final log = MemoryEventLog();
        await tester.pumpWidget(app(log));
        await tester.pumpAndSettle();
        await openSetup(tester);

        await revealFound(tester, find.text('Skilled'));
        await tester.tap(find.text('Skilled'));
        await tester.pump();
        await reveal(tester, 'rule-seventh-card');
        await tester.tap(find.byKey(const ValueKey('rule-seventh-card')));
        await tester.pump();
        await reveal(tester, 'start-match');
        await startMatch(tester);

        final created = (await log.events(
          (await log.unfinishedMatch('twentynine'))!,
        )).first;
        expect(created.type, EventTypes.matchCreated);
        final rules = created.payload['rules']! as Map<String, Object?>;
        expect(rules['seventhCard'], isFalse);
        expect(rules['minBid'], 16);
        final seats = created.payload['seats']! as List<Object?>;
        expect(seats.whereType<Map<String, Object?>>().map((s) => s['level']), [
          null,
          'skilled',
          'skilled',
          'skilled',
        ]);
      },
    );

    testWidgets('a full offline deal, played by tapping on $screen', (
      tester,
    ) async {
      useScreen(tester, size, ratio);
      final log = MemoryEventLog();
      await tester.pumpWidget(app(log));
      await tester.pumpAndSettle();
      await openSetup(tester);
      await reveal(tester, 'start-match');
      await startMatch(tester);

      // Four cards each before the auction; the player sits at the bottom.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TwentyNineTableScreen)),
      );
      expect(container.read(offlineMatchProvider)!.view.hand, hasLength(4));
      expect(find.byKey(const ValueKey('seat-2')), findsOneWidget);

      await playUntil(
        tester,
        () => find.byKey(const ValueKey('deal-result')).evaluate().isNotEmpty,
      );
      final result = container.read(offlineMatchProvider)!.dealResult!;
      expect(find.byKey(const ValueKey('next-deal')), findsOneWidget);

      final matchId = container.read(offlineMatchProvider)!.matchId;
      final events = await log.events(matchId);
      expect(verifyChain(events), isNull);
      expect(
        events.where((e) => e.type == 'twentynine.dealScored'),
        hasLength(1),
      );
      expect(
        events.where(
          (e) => e.type == 'twentynine.cardPlayed' && e.actor == 'seat:0',
        ),
        isNotEmpty,
        reason: 'the player played cards by tapping',
      );

      // In a short window the result panel scrolls to its button.
      await tester.ensureVisible(find.byKey(const ValueKey('next-deal')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('next-deal')));
      await tester.pump();
      final after = container.read(offlineMatchProvider)!;
      expect(after.dealResult, isNull);
      if (result.scores.every((score) => score.abs() < 6)) {
        expect(after.view.dealNumber, 2);
      }
    });
  }

  testWidgets('leaving a match asks first, then quits the game', (
    tester,
  ) async {
    useScreen(tester, screens.first.$2, screens.first.$3);
    final log = MemoryEventLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await openSetup(tester);
    await reveal(tester, 'start-match');
    await startMatch(tester);
    final matchId = (await log.unfinishedMatch('twentynine'))!;

    await tester.tap(find.byKey(const ValueKey('leave-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stay')));
    await tester.pumpAndSettle();
    expect(find.byType(TwentyNineTableScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('leave-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leave')));
    await tester.pumpAndSettle();
    expect(find.byType(TwentyNineTableScreen), findsNothing);
    expect(find.byKey(const ValueKey('game-twentynine')), findsOneWidget);
    expect(log.statusOf(matchId), MatchStatus.abandoned);
    final types = [for (final e in await log.events(matchId)) e.type];
    expect(types.skip(types.length - 3), [
      EventTypes.matchAbandoned,
      EventTypes.rewardPending,
      EventTypes.seriesEnded,
    ]);
  });
}
