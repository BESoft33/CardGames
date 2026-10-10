import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_protocol/sync_protocol.dart';

import '../../data/event_log.dart';
import '../../data/identity.dart';
import '../../data/local_database.dart';
import '../../data/providers.dart';
import '../../data/remote/auth_repository.dart';
import '../../data/remote/game_server.dart';
import '../../data/remote/providers.dart';
import '../../data/sync/sync_engine.dart';
import '../games/twentynine/offline_match.dart';

/// Where the app stands with the server.
enum SyncPhase {
  /// This build has no online services: offline play only.
  unavailable,

  /// Up to date, or not tried yet.
  idle,

  /// Uploading now.
  syncing,

  /// The server or Auth could not be reached; a retry is scheduled.
  offline,

  /// The signed-in account's session ended elsewhere; sign in again.
  signedOutElsewhere,

  /// Accounts work, but this build has no game server yet: progress stays
  /// on the phone and coins are not confirmed.
  noServer,
}

/// The profile in use and its sync status.
final class AccountState {
  /// Creates a state.
  const AccountState({
    required this.profile,
    required this.phase,
    this.lastSynced,
  });

  /// The profile in use.
  final LocalProfile profile;

  /// Where sync stands.
  final SyncPhase phase;

  /// When the last sync finished, in this run of the app.
  final DateTime? lastSynced;
}

/// How a Google sign-in ended, for the screen to say.
sealed class SignInOutcome {
  const SignInOutcome();
}

/// Signed in: the guest's account is now a Google account.
final class SignedUp extends SignInOutcome {
  /// Creates the outcome; [bonus] is the sign-up bonus paid, or 0.
  const SignedUp(this.bonus, {this.bonusLater = false});

  /// The sign-up bonus paid, or 0 if this Google account had it before.
  final int bonus;

  /// Whether the bonus, if due, waits for the game server: this build has
  /// none yet, and the server pays it the first time it sees the account.
  final bool bonusLater;
}

/// Signed in to an existing account; the guest's winnings moved into it.
final class SignedInExisting extends SignInOutcome {
  /// Creates the outcome.
  const SignedInExisting(this.coinsMoved);

  /// The coins the guest brought.
  final int coinsMoved;
}

/// The player closed the Google sign-in.
final class SignInCancelled extends SignInOutcome {
  /// Creates the outcome.
  const SignInCancelled();
}

/// Signing in needs a connection, and there is none.
final class SignInOffline extends SignInOutcome {
  /// Creates the outcome.
  const SignInOffline();
}

/// The profile in use, sign-in, sign-out and sync (AGENTS.md §9, §10).
final accountProvider = AsyncNotifierProvider<AccountController, AccountState>(
  AccountController.new,
);

/// Runs [accountProvider].
class AccountController extends AsyncNotifier<AccountState> {
  Timer? _retry;
  int _failures = 0;
  Future<SyncReport?>? _running;
  final math.Random _jitter = math.Random();

  /// The longest wait between retries.
  static const Duration maxRetryDelay = Duration(minutes: 10);

  AuthRepository? get _auth => ref.read(authRepositoryProvider);
  GameServer? get _server => ref.read(gameServerProvider);

  @override
  Future<AccountState> build() async {
    ref.onDispose(() => _retry?.cancel());
    // Rebuilt when the profile in use changes, which changes the log.
    await ref.watch(eventLogProvider.future);
    final accounts = await ref.watch(accountStoreProvider.future);
    return AccountState(
      profile: await accounts.active(),
      phase: _auth == null ? SyncPhase.unavailable : SyncPhase.idle,
    );
  }

  Future<AccountStore> get _accounts => ref.read(accountStoreProvider.future);

  void _publish(LocalProfile profile, SyncPhase phase, {DateTime? synced}) {
    if (!ref.mounted) return;
    state = AsyncData(
      AccountState(
        profile: profile,
        phase: phase,
        lastSynced: synced ?? state.value?.lastSynced,
      ),
    );
  }

  /// Uploads what waits, if this build is online (AGENTS.md §9). Called on
  /// start, when the app comes back to the foreground, after a match ends
  /// and after sign-in. A failure schedules a retry with exponential
  /// back-off and jitter. Returns null if nothing ran.
  Future<SyncReport?> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncReport?> _sync() async {
    final auth = _auth;
    final server = _server;
    if (auth == null) return null;
    // Let the first build finish, so it cannot overwrite what sync reports.
    await future;
    if (!ref.mounted) return null;
    final accounts = await _accounts;
    var profile = await accounts.active();
    _publish(profile, SyncPhase.syncing);
    try {
      final session = await _sessionFor(profile, auth, accounts);
      if (session == null) {
        _publish(profile, SyncPhase.signedOutElsewhere);
        return null;
      }
      profile = await accounts.active();
      if (server == null) {
        // The guest has its account, ready for sign-in; nothing else can be
        // done without the game server.
        _publish(profile, SyncPhase.noServer);
        return null;
      }
      final engine = SyncEngine(server);
      SyncReport? report;
      // The profile in use, and any older profile of the same account on
      // this device, such as one left with events at sign-out.
      for (final other in await accounts.all()) {
        if (other.profileId == profile.profileId ||
            other.remoteUserId != profile.remoteUserId) {
          continue;
        }
        if (!ref.mounted) return null;
        await engine.sync(await _logFor(other), session.accessToken);
      }
      // The profile in use may have changed meanwhile, which rebuilds this
      // controller; the new one syncs it.
      if (!ref.mounted) return null;
      report = await engine.sync(
        await ref.read(eventLogProvider.future),
        session.accessToken,
      );
      profile = profile.copyWith(confirmedBalance: report.balance);
      await accounts.save(profile);
      _failures = 0;
      _retry?.cancel();
      _publish(profile, SyncPhase.idle, synced: DateTime.now());
      if (!ref.mounted) return report;
      if (ref.mounted) ref.invalidate(walletProvider);
      return report;
    } on AuthUnavailable {
      _scheduleRetry(profile);
    } on ServerUnavailable {
      _scheduleRetry(profile);
    } on Exception {
      // A refusal, or something unexpected: nothing is lost, and the next
      // attempt starts from what the server holds.
      _scheduleRetry(profile);
    }
    return null;
  }

  Future<EventLog> _logFor(LocalProfile profile) async =>
      (await ref.read(profileLogsProvider.future))(profile.profileId);

  /// The session of [profile]'s account. A guest going online for the first
  /// time gets an anonymous account (AGENTS.md §10). Null if a signed-in
  /// account's session has ended.
  Future<RemoteSession?> _sessionFor(
    LocalProfile profile,
    AuthRepository auth,
    AccountStore accounts,
  ) async {
    final remote = profile.remoteUserId;
    if (remote != null) {
      final session = await auth.session(remote);
      if (session != null || !profile.isGuest) return session;
    }
    final session = await auth.signInAsGuest();
    await accounts.save(profile.copyWith(remoteUserId: session.userId));
    return session;
  }

  void _scheduleRetry(LocalProfile profile) {
    _failures++;
    final base = const Duration(seconds: 5) * math.pow(2, _failures - 1);
    final capped = base > maxRetryDelay ? maxRetryDelay : base;
    final delay = capped * (0.5 + _jitter.nextDouble());
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (ref.mounted) unawaited(sync());
    });
    _publish(profile, SyncPhase.offline);
  }

  /// Signs in with Google (AGENTS.md §10). Needs a connection. A new Google
  /// account takes over the guest's account and earns the sign-up bonus;
  /// an existing one is signed in to, and the server moves the guest's
  /// winnings into it.
  Future<SignInOutcome> signInWithGoogle() async {
    final auth = _auth;
    final server = _server;
    if (auth == null) return const SignInOffline();
    final accounts = await _accounts;
    // Go online as the guest first, and upload what it has.
    await sync();
    if (!ref.mounted) return const SignInOffline();
    final guest = await accounts.active();
    final guestUser = guest.remoteUserId;
    if (guestUser == null || state.value?.phase == SyncPhase.offline) {
      return const SignInOffline();
    }
    final GoogleSignInResult result;
    try {
      result = await auth.signInWithGoogle(guestUserId: guestUser);
    } on AuthUnavailable {
      return const SignInOffline();
    }
    try {
      switch (result) {
        case GoogleCancelled():
          return const SignInCancelled();
        case GoogleLinked(:final displayName) when server == null:
          await accounts.save(
            guest.copyWith(kind: ProfileKind.google, displayName: displayName),
          );
          _switched();
          return const SignedUp(0, bonusLater: true);
        case GoogleLinked(:final session, :final displayName):
          final wallet = await server!.wallet(session.accessToken);
          await accounts.save(
            guest.copyWith(
              kind: ProfileKind.google,
              displayName: displayName,
              confirmedBalance: wallet.balance,
            ),
          );
          _switched();
          return SignedUp(
            wallet.credited
                .where((c) => c.reason == CoinReason.googleSignupBonus)
                .fold(0, (sum, c) => sum + c.amount),
          );
        case GoogleSwitched(:final session, :final displayName):
          // Without a game server no server has seen the guest, so there is
          // nothing to merge: its matches go up under the account later.
          final guestSession = server == null
              ? null
              : await auth.session(guestUser);
          final merged = guestSession == null
              ? null
              : await server!.merge(
                  guestSession.accessToken,
                  session.accessToken,
                );
          await auth.signOut(guestUser);
          final balance = server == null
              ? null
              : merged?.wallet.balance ??
                    (await server.wallet(session.accessToken)).balance;
          // The guest's profile now belongs to the account, as on the
          // server; the account's own profile here, if any, is used.
          final known = await accounts.byRemoteUser(session.userId);
          await accounts.save(
            guest.copyWith(
              kind: ProfileKind.google,
              remoteUserId: session.userId,
              displayName: displayName,
              confirmedBalance: balance,
            ),
          );
          final target = known ?? guest;
          await accounts.save(
            (await accounts.profile(target.profileId))!.copyWith(
              kind: ProfileKind.google,
              displayName: displayName,
              confirmedBalance: balance,
            ),
          );
          await accounts.setActive(target.profileId);
          _switched();
          return SignedInExisting(merged?.coinsMoved ?? 0);
      }
    } on ServerUnavailable {
      return const SignInOffline();
    }
  }

  /// Signs out (AGENTS.md §10): uploads what it can, revokes the session,
  /// deletes its tokens and returns to a new guest. Returns true if some
  /// progress could not be uploaded; it stays on this device, encrypted,
  /// and goes up at the next sign-in.
  Future<bool> signOut() async {
    final auth = _auth;
    final accounts = await _accounts;
    final profile = await accounts.active();
    final remote = profile.remoteUserId;
    if (auth == null || profile.isGuest || remote == null) return false;
    await sync();
    if (!ref.mounted) return false;
    final log = await ref.read(eventLogProvider.future);
    final left = await log.uploadStates();
    await auth.signOut(remote);
    final guest = await accounts.newGuest();
    await accounts.setActive(guest.profileId);
    _switched();
    return left.isNotEmpty;
  }

  /// Starts afresh everything that belongs to the profile in use, this
  /// controller included. Call nothing on it afterwards; ask
  /// [accountProvider] for the new one.
  void _switched() {
    if (!ref.mounted) return;
    ref
      ..invalidate(offlineMatchProvider)
      ..invalidate(identityProvider)
      ..invalidate(eventLogProvider)
      ..invalidate(settingsStoreProvider)
      ..invalidate(walletProvider)
      ..invalidateSelf();
  }
}
