import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:card_games/features/games/twentynine/setup_screen.dart';
import 'package:card_games/features/games/twentynine/table_screen.dart';
import 'package:card_games/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/test_app.dart';

/// Opens the setup of a Twenty-Nine match from the lobby, on a tall phone.
Future<void> openSetup(
  WidgetTester tester,
  EventLog log, {
  SettingsStore? settings,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(log, settings: settings));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('game-twentynine')));
  await tester.pumpAndSettle();
  expect(find.byType(TwentyNineSetupScreen), findsOneWidget);
}

/// Scrolls to the start button and taps it.
Future<void> tapStart(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('start-match')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('start-match')));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// The match the log records as created most recently.
Future<EventEnvelope> newestCreated(EventLog log) async =>
    (await log.events((await log.unfinishedMatch('twentynine'))!)).first;

void main() {
  testWidgets('a match is played at the table fee by default', (tester) async {
    final log = MemoryEventLog();
    await openSetup(tester, log);
    expect(
      textOf(tester, 'stakes-help'),
      'Each match costs 100 EC. Every deal your team wins pays you 5 EC, '
      'winning the match pays 200 EC, and losing it costs 50 EC more.',
    );
    expect(textOf(tester, 'stakes-balance'), 'You have 1,000 EC.');

    await tapStart(tester);
    expect(find.byType(TwentyNineTableScreen), findsOneWidget);
    final matchId = (await log.unfinishedMatch('twentynine'))!;
    final events = await log.events(matchId);
    expect(events.first.payload['stake'], 100);
    expect(events[1].type, EventTypes.entryFee);
    expect(find.text('100 EC table'), findsOneWidget);
  });

  testWidgets('practice is free', (tester) async {
    final log = MemoryEventLog();
    await openSetup(
      tester,
      log,
      settings: MemorySettingsStore({'stake': '500'}),
    );
    expect(find.text('500 EC table'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stakes-practice')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'stakes-help'), 'No fee, and no coins to win.');

    await tapStart(tester);
    expect((await newestCreated(log)).payload['stake'], 0);
    final events = await log.events((await log.unfinishedMatch('twentynine'))!);
    expect(events.where((e) => e.type.startsWith('economy.')), isEmpty);
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('a player who cannot pay the fee plays practice', (tester) async {
    final log = MemoryEventLog();
    await openSetup(
      tester,
      log,
      settings: MemorySettingsStore({'stake': '5000'}),
    );
    final choice = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(choice.selected, {true}, reason: 'practice is chosen for them');
    expect(choice.segments.first.enabled, isFalse);
    expect(
      textOf(tester, 'stakes-balance'),
      'You have 1,000 EC, not enough for this table. Play practice, or '
      'choose a smaller fee in Settings.',
    );

    await tapStart(tester);
    expect((await newestCreated(log)).payload['stake'], 0);
  });

  testWidgets('the fee can be changed from the setup', (tester) async {
    await openSetup(tester, MemoryEventLog());
    await tester.tap(find.byKey(const ValueKey('change-table-fee')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('table-fee-1000')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1,000 EC table'), findsOneWidget);
  });

  testWidgets('an unfinished game ends only once the player agrees', (
    tester,
  ) async {
    final log = MemoryEventLog();
    await log.append(
      'old',
      const [
        NewEvent(EventTypes.matchCreated, Actors.user, {'stake': 0}),
      ],
      gameId: 'twentynine',
      rulesVersion: 1,
    );
    await openSetup(tester, log);
    expect(find.byKey(const ValueKey('continue-match')), findsOneWidget);

    await tapStart(tester);
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-new-match')));
    await tester.pumpAndSettle();
    expect(find.byType(TwentyNineSetupScreen), findsOneWidget);
    expect(log.statusOf('old'), MatchStatus.active);

    await tapStart(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-new-match')));
    await tester.pumpAndSettle();
    expect(find.byType(TwentyNineTableScreen), findsOneWidget);
    expect(log.statusOf('old'), MatchStatus.abandoned);
    expect((await log.events('old')).map((e) => e.type), [
      EventTypes.matchCreated,
    ], reason: 'a log that does not replay is closed as it is');
  });

  testWidgets('every bot level can be chosen, each described', (tester) async {
    final log = MemoryEventLog();
    await openSetup(tester, log);
    expect(
      textOf(tester, 'level-help'),
      'Plays sensibly, but forgets earlier tricks.',
    );
    for (final (level, help) in [
      ('beginner', 'Still learning, and makes mistakes.'),
      ('skilled', 'Counts every card played.'),
      ('expert', 'Works each deal out to the end.'),
      ('master', 'Also reads the bidding. The strongest.'),
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey('level-$level')));
      await tester.tap(find.byKey(ValueKey('level-$level')));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'level-help'), help);
    }

    await tapStart(tester);
    final seats = (await newestCreated(log)).payload['seats']! as List;
    expect(
      [for (final seat in seats.cast<Map<String, Object?>>()) seat['level']]
          .whereType<String>(),
      ['master', 'master', 'master'],
    );
  });

  testWidgets('the five levels fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(MemoryEventLog()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-twentynine')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    for (final level in ['beginner', 'casual', 'skilled', 'expert', 'master']) {
      expect(find.byKey(ValueKey('level-$level')), findsOneWidget);
    }
  });
}
