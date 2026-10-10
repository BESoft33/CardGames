import 'package:card_games/app/app.dart';
import 'package:card_games/app/backend_config.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/remote/auth_repository.dart';
import 'package:card_games/data/remote/providers.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/test_app.dart';
import 'account_flow_test.dart' show online, supabaseOnly;

void main() {
  late FakeAuthRepository auth;
  late InProcessServer server;
  late MemoryAccountStore accounts;
  late Map<String, MemoryEventLog> logs;

  // Made inside each test, in its fake-time zone: futures made in setUp
  // would complete outside it, where pumping never runs them.
  void start() {
    auth = FakeAuthRepository();
    server = InProcessServer(auth);
    accounts = MemoryAccountStore(guestId: uuidV7());
    logs = {};
  }

  MemoryEventLog logOf(String profileId) => logs.putIfAbsent(
    profileId,
    () => MemoryEventLog(
      identity: LocalIdentity(deviceId: 'device', userId: profileId),
    ),
  );

  Future<void> openSettings(
    WidgetTester tester, {
    BackendConfig? config,
  }) async {
    start();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventLogProvider.overrideWith(
            (ref) async => logOf((await accounts.active()).profileId),
          ),
          profileLogsProvider.overrideWith((ref) async => logOf),
          accountStoreProvider.overrideWith((ref) async => accounts),
          settingsStoreProvider.overrideWith(
            (ref) async => MemorySettingsStore(),
          ),
          backendConfigProvider.overrideWithValue(config ?? online),
          if ((config ?? online).hasSupabase)
            authRepositoryProvider.overrideWithValue(auth),
          if ((config ?? online).hasServer)
            gameServerProvider.overrideWithValue(server),
          ...instantBots(),
        ],
        child: const CardGamesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('a guest signs up with Google and gets the bonus', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('Guest'), findsOneWidget);
    expect(
      find.text('First sign-up with Google: 2,500 EC bonus.'),
      findsOneWidget,
    );
    expect(find.text('Your progress is up to date.'), findsOneWidget);

    auth.nextGoogleSubject = 'google-widget';
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    expect(
      find.text('Welcome! Your 2,500 EC sign-up bonus has been added.'),
      findsOneWidget,
    );
    expect(find.text('Signed in as Test Player'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-out')), findsOneWidget);
    final profile = await accounts.active();
    expect(profile.kind, ProfileKind.google);
    expect(server.balanceOf(profile.remoteUserId!), 3500);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Test Player'), findsOneWidget);
    expect(find.text('3,500 EC'), findsOneWidget, reason: 'the coins button');
  });

  testWidgets('signing out asks first and returns to a new guest', (
    tester,
  ) async {
    await openSettings(tester);
    auth.nextGoogleSubject = 'google-widget-2';
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    final signedIn = await accounts.active();

    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-sign-out')));
    await tester.pumpAndSettle();
    expect((await accounts.active()).profileId, signedIn.profileId);

    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await tester.pumpAndSettle();
    final guest = await accounts.active();
    expect(guest.isGuest, isTrue);
    expect(guest.profileId, isNot(signedIn.profileId));
    expect(auth.signedOut, [signedIn.remoteUserId]);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-google')), findsOneWidget);
  });

  testWidgets('a build without online services says so', (tester) async {
    await openSettings(tester, config: BackendConfig.offline);
    expect(find.byKey(const ValueKey('sign-in-google')), findsNothing);
    expect(
      find.text(
        'Online features are not set up in this build. You can play offline.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a cancelled sign-in leaves the guest as it was', (tester) async {
    await openSettings(tester);
    auth.nextGoogleSubject = null;
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    expect(find.text('Guest'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('offline, signing in says it needs a connection', (tester) async {
    await openSettings(tester);
    server.online = false;
    auth.nextGoogleSubject = 'google-offline';
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Signing in needs a connection. Try again when you are online.',
      ),
      findsOneWidget,
    );
    expect((await accounts.active()).isGuest, isTrue);
    // A retry is scheduled; stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('before the game server exists, sign-in works and says the '
      'bonus comes later', (tester) async {
    await openSettings(tester, config: supabaseOnly);
    expect(
      find.text(
        'Your progress is kept on this phone. Coins sync once the game '
        'server is set up.',
      ),
      findsOneWidget,
    );
    auth.nextGoogleSubject = 'google-before-server';
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Signed in. Your sign-up bonus is added when your coins first sync.',
      ),
      findsOneWidget,
    );
    expect(find.text('Signed in as Test Player'), findsOneWidget);
  });
}
