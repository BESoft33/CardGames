import 'package:bots/bots.dart';
import 'package:card_games/app/backend_config.dart';
import 'package:card_games/data/event_log.dart';
import 'package:card_games/data/identity.dart';
import 'package:card_games/data/local_database.dart';
import 'package:card_games/data/providers.dart';
import 'package:card_games/data/remote/auth_repository.dart';
import 'package:card_games/data/remote/providers.dart';
import 'package:card_games/data/settings_store.dart';
import 'package:card_games/features/account/account_controller.dart';
import 'package:card_games/features/games/twentynine/offline_match.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_twentynine/game_twentynine.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../helpers/fake_server.dart';
import '../../helpers/test_app.dart';

/// A build with online services, as the env file gives them.
const BackendConfig online = BackendConfig(
  supabaseUrl: 'https://example.supabase.co',
  supabaseKey: 'publishable',
  serverUrl: 'https://server.example.com',
  googleWebClientId: 'web.apps.googleusercontent.com',
  googleIosClientId: '',
);

/// A build with Supabase but no game server yet.
const BackendConfig supabaseOnly = BackendConfig(
  supabaseUrl: 'https://example.supabase.co',
  supabaseKey: 'publishable',
  serverUrl: '',
  googleWebClientId: 'web.apps.googleusercontent.com',
  googleIosClientId: '',
);

/// One phone: its accounts, profile logs and providers, talking to [auth]
/// and, if [withServer], to [server].
final class Phone {
  Phone(this.auth, this.server, {this.withServer = true}) {
    final first = MemoryEventLog(
      identity: LocalIdentity(deviceId: uuidV7(), userId: uuidV7()),
    );
    accounts = MemoryAccountStore(guestId: first.identity.userId);
    logs[first.identity.userId] = first;
    container = ProviderContainer.test(overrides: overrides());
  }

  final FakeAuthRepository auth;
  final InProcessServer server;
  bool withServer;
  late final MemoryAccountStore accounts;
  final Map<String, MemoryEventLog> logs = {};
  late ProviderContainer container;

  /// Starts the app again, keeping what the phone stores, with or without
  /// a game server: as after installing a newer build.
  void restart({required bool withServer}) {
    container.dispose();
    this.withServer = withServer;
    container = ProviderContainer.test(overrides: overrides());
  }

  MemoryEventLog logOf(String profileId) => logs.putIfAbsent(
    profileId,
    () => MemoryEventLog(
      identity: LocalIdentity(
        deviceId: logs.values.first.identity.deviceId,
        userId: profileId,
      ),
    ),
  );

  List<Override> overrides() => [
    // The log follows the profile in use, as in the app.
    eventLogProvider.overrideWith(
      (ref) async => logOf((await accounts.active()).profileId),
    ),
    profileLogsProvider.overrideWith((ref) async => logOf),
    accountStoreProvider.overrideWith((ref) async => accounts),
    settingsStoreProvider.overrideWith((ref) async => MemorySettingsStore()),
    backendConfigProvider.overrideWithValue(withServer ? online : supabaseOnly),
    authRepositoryProvider.overrideWithValue(auth),
    gameServerProvider.overrideWithValue(withServer ? server : null),
    ...instantBots(),
  ];

  AccountController get account => container.read(accountProvider.notifier);

  Future<LocalProfile> profile() => accounts.active();

  /// Plays a whole staked match as the profile in use, then votes to end
  /// its game, so the match is complete (AGENTS.md §6.13).
  Future<String> playMatch({int stake = 500}) async {
    await container.read(accountProvider.future);
    final controller = container.read(offlineMatchProvider.notifier);
    await controller.start(
      const TwentyNineConfig(),
      BotLevel.casual,
      stake: stake,
    );
    final matchId = container.read(offlineMatchProvider)!.matchId;
    for (var step = 0; step < 20000; step++) {
      await pumpEventQueue();
      final table = container.read(offlineMatchProvider)!;
      if (table.view.phase == TwentyNinePhase.matchOver) {
        await controller.vote(continueGame: false);
        return matchId;
      }
      if (table.dealResult != null) {
        controller.dismissDealResult();
      } else if (table.view.isMyTurn) {
        await controller.act(
          const DirectBotRunner().decide(table.view, BotLevel.skilled, step),
        );
      }
    }
    fail('the match did not end');
  }
}

void main() {
  late FakeAuthRepository auth;
  late InProcessServer server;

  setUp(() {
    auth = FakeAuthRepository();
    server = InProcessServer(auth);
  });

  test('a guest goes online silently and its gift is confirmed', () async {
    final phone = Phone(auth, server);
    await phone.container.read(accountProvider.future);
    final report = await phone.account.sync();
    final profile = await phone.profile();
    expect(profile.isGuest, isTrue);
    expect(profile.remoteUserId, isNotNull, reason: 'an anonymous account');
    expect(auth.accounts['token-${profile.remoteUserId}']!.isAnonymous, isTrue);
    expect(report!.balance, 1000);
    expect(profile.confirmedBalance, 1000);
    final wallet = await phone.container.read(walletProvider.future);
    expect(wallet.confirmed, 1000);
    expect(wallet.pending, isEmpty, reason: 'the gift is confirmed now');
    expect(phone.container.read(accountProvider).value!.phase, SyncPhase.idle);
  });

  test('offline, sync waits and retries; nothing is lost', () async {
    final phone = Phone(auth, server);
    await phone.container.read(accountProvider.future);
    auth.online = false;
    expect(await phone.account.sync(), isNull);
    expect(
      phone.container.read(accountProvider).value!.phase,
      SyncPhase.offline,
    );
    auth.online = true;
    expect((await phone.account.sync())!.balance, 1000);
    expect(phone.container.read(accountProvider).value!.phase, SyncPhase.idle);
  });

  test(
    'a first sign-up with Google keeps the guest and pays the bonus',
    () async {
      final phone = Phone(auth, server);
      final matchId = await phone.playMatch();
      auth.nextGoogleSubject = 'google-1';
      final outcome = await phone.account.signInWithGoogle();
      expect(outcome, isA<SignedUp>().having((o) => o.bonus, 'bonus', 2500));
      // The match went up as the guest's, before signing in.
      final coins = server.store.matchOf(matchId)!.coins!;
      final profile = await phone.profile();
      expect(profile.kind, ProfileKind.google);
      expect(profile.displayName, 'Test Player');
      expect(profile.confirmedBalance, 1000 + coins + 2500);
      expect(server.balanceOf(profile.remoteUserId!), 1000 + coins + 2500);
    },
  );

  test('sync after sign-in from guest: an existing account takes in the '
      "guest's winnings, not its gift (AGENTS.md §9, §10)", () async {
    // The Google account already exists, from another phone.
    final other = Phone(auth, server);
    auth.nextGoogleSubject = 'google-2';
    await other.account.signInWithGoogle();
    final account = (await other.profile()).remoteUserId!;
    expect(server.balanceOf(account), 3500);

    final phone = Phone(auth, server);
    final matchId = await phone.playMatch();
    final outcome = await phone.account.signInWithGoogle();
    // The guest's match went up before the merge; the server kept its coins.
    final net = server.store.matchOf(matchId)!.coins!;
    final moved = net > 0 ? net : 0;
    expect(
      outcome,
      isA<SignedInExisting>().having((o) => o.coinsMoved, 'moved', moved),
    );
    final profile = await phone.profile();
    expect(profile.remoteUserId, account);
    expect(profile.kind, ProfileKind.google);
    expect(server.balanceOf(account), 3500 + moved, reason: 'no second gift');
    expect(profile.confirmedBalance, 3500 + moved);
  });

  test('signing out keeps unsent progress for the next sign-in', () async {
    final phone = Phone(auth, server);
    auth.nextGoogleSubject = 'google-3';
    await phone.account.signInWithGoogle();
    final signedIn = await phone.profile();
    // Offline, a match is played and cannot be uploaded.
    server.online = false;
    final matchId = await phone.playMatch();
    final unsent = await phone.account.signOut();
    expect(unsent, isTrue);
    final guest = await phone.profile();
    expect(guest.isGuest, isTrue);
    expect(guest.profileId, isNot(signedIn.profileId));
    expect(auth.signedOut, [signedIn.remoteUserId]);
    expect(
      await phone.logOf(signedIn.profileId).events(matchId),
      isNotEmpty,
      reason: 'kept on the phone',
    );

    // Back online, signing in again finds the account's profile and uploads
    // what it kept.
    server.online = true;
    final outcome = await phone.account.signInWithGoogle();
    expect(outcome, isA<SignedInExisting>());
    final back = await phone.profile();
    expect(back.profileId, signedIn.profileId);
    await phone.account.sync();
    expect(await phone.logOf(signedIn.profileId).uploadStates(), isEmpty);
    expect(server.store.matchOf(matchId)!.status, MatchSyncStatus.accepted);
  });

  test('a cancelled sign-in changes nothing', () async {
    final phone = Phone(auth, server);
    auth.nextGoogleSubject = null;
    expect(await phone.account.signInWithGoogle(), isA<SignInCancelled>());
    expect((await phone.profile()).isGuest, isTrue);
  });

  test(
    'without online services, sign-in says so and sync does nothing',
    () async {
      final log = MemoryEventLog();
      final container = ProviderContainer.test(overrides: memoryOverrides(log));
      await container.read(accountProvider.future);
      expect(
        container.read(accountProvider).value!.phase,
        SyncPhase.unavailable,
      );
      expect(await container.read(accountProvider.notifier).sync(), isNull);
      expect(
        await container.read(accountProvider.notifier).signInWithGoogle(),
        isA<SignInOffline>(),
      );
    },
  );

  group('before the game server is set up (D-030)', () {
    test('a guest still gets its account, ready to sign in', () async {
      final phone = Phone(auth, server, withServer: false);
      await phone.container.read(accountProvider.future);
      expect(await phone.account.sync(), isNull);
      final profile = await phone.profile();
      expect(profile.remoteUserId, isNotNull);
      expect(
        phone.container.read(accountProvider).value!.phase,
        SyncPhase.noServer,
      );
      expect(server.uploads, 0);
    });

    test(
      'a first sign-up links the guest; the bonus waits for the server',
      () async {
        final phone = Phone(auth, server, withServer: false);
        auth.nextGoogleSubject = 'google-early';
        final outcome = await phone.account.signInWithGoogle();
        expect(
          outcome,
          isA<SignedUp>()
              .having((o) => o.bonus, 'bonus', 0)
              .having((o) => o.bonusLater, 'later', isTrue),
        );
        final profile = await phone.profile();
        expect(
          (profile.kind, profile.displayName),
          (ProfileKind.google, 'Test Player'),
        );
        expect(server.balanceOf(profile.remoteUserId!), 0, reason: 'not yet');

        // A build with the server pays the gift and the bonus at first sync.
        phone.restart(withServer: true);
        await phone.container.read(accountProvider.future);
        final report = await phone.account.sync();
        expect(report!.balance, 3500);
        expect(report.credited.map((c) => c.reason), [
          CoinReason.welcomeGift,
          CoinReason.googleSignupBonus,
        ]);
      },
    );

    test(
      "signing in to an existing account takes the guest's matches along",
      () async {
        final other = Phone(auth, server);
        auth.nextGoogleSubject = 'google-known';
        await other.account.signInWithGoogle();
        final account = (await other.profile()).remoteUserId!;

        final phone = Phone(auth, server, withServer: false);
        final matchId = await phone.playMatch();
        final outcome = await phone.account.signInWithGoogle();
        expect(
          outcome,
          isA<SignedInExisting>().having((o) => o.coinsMoved, 'moved', 0),
        );
        final profile = await phone.profile();
        expect(profile.remoteUserId, account);

        phone.restart(withServer: true);
        await phone.container.read(accountProvider.future);
        await phone.account.sync();
        final record = server.store.matchOf(matchId)!;
        expect(
          (record.userId, record.status),
          (account, MatchSyncStatus.accepted),
        );
        expect(server.balanceOf(account), 3500 + record.coins!);
      },
    );
  });
}
