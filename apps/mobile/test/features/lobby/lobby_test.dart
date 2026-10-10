import 'package:card_games/app/app.dart';
import 'package:card_games/app/games.dart';
import 'package:card_games/app/routes.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/features/settings/settings_screen.dart';
import 'package:card_games/features/wallet/wallet_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/test_app.dart';

/// The text on the coins button in the lobby.
String coinsShown(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('wallet-chip')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  testWidgets('the lobby lists the games of the registry (AGENTS.md §5.9)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...memoryOverrides(MemoryEventLog()),
          gameEntriesProvider.overrideWithValue([
            GameEntry(
              game: const TwentyNineGame(),
              route: AppRoutes.settings,
              name: (_) => 'A registered game',
              subtitle: (_) => 'Listed from its entry',
            ),
          ]),
        ],
        child: const CardGamesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A registered game'), findsOneWidget);
    expect(find.text('Listed from its entry'), findsOneWidget);
    expect(find.text('Twenty-Nine'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('game-twentynine')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the coins button shows what the player can spend and opens '
      'the wallet', (tester) async {
    final log = MemoryEventLog();
    await log.append(
      'm1',
      [
        const NewEvent(EventTypes.matchCreated, Actors.user, {'stake': 500}),
        NewEvent(
          EventTypes.entryFee,
          Actors.user,
          EconomyPayloads.entryFee(stake: 500, seats: 4, humans: 1),
        ),
      ],
      gameId: 'twentynine',
      rulesVersion: 1,
    );
    await tester.pumpWidget(testApp(log));
    await tester.pumpAndSettle();
    expect(coinsShown(tester), '500 EC');

    await tester.tap(find.byKey(const ValueKey('wallet-chip')));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.text('Twenty-Nine, 500 EC table'), findsOneWidget);
  });

  testWidgets('the settings button opens the settings', (tester) async {
    await tester.pumpWidget(testApp(MemoryEventLog()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('guest start: the first launch makes a guest with the starting '
      'gift, and keeps their settings (AGENTS.md §10)', (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        localDatabaseProvider.overrideWith((ref) async => db),
        ...instantBots(),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CardGamesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Playing as a guest'), findsOneWidget);
    expect(coinsShown(tester), '1,000 EC');
    final ids = {
      for (final row in await db.select(db.meta).get()) row.key: row.value,
    };
    expect(isUuid(ids['device_id']!), isTrue);
    final guestId = ids['active_profile_id']!;
    expect(isUuid(guestId), isTrue);
    final profile = await db.select(db.profiles).getSingle();
    expect((profile.profileId, profile.kind), (guestId, ProfileKind.guest));
    expect(profile.remoteUserId, isNull, reason: 'not online yet');
    expect(
      (await container.read(eventLogProvider.future)).identity.userId,
      guestId,
    );

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('table-fee-500')));
    await tester.pumpAndSettle();
    final saved = await db.select(db.settings).getSingle();
    expect((saved.userId, saved.key, saved.value), (guestId, 'stake', '500'));
  });
}
