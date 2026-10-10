import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/version.dart';
import 'database_opener.dart';
import 'event_log.dart';
import 'identity.dart';
import 'local_database.dart';
import 'settings_store.dart';
import 'wallet.dart';

/// Where the local database key is kept.
final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => const SecureDatabaseKeyStore(),
);

/// The encrypted local database, opened on first use.
final localDatabaseProvider = FutureProvider<LocalDatabase>((ref) async {
  final db = await openLocalDatabase(ref.watch(databaseKeyStoreProvider));
  ref.onDispose(db.close);
  return db;
});

/// This device and the user the app records for: the guest profile made on
/// first launch (AGENTS.md §10).
final identityProvider = FutureProvider<LocalIdentity>((ref) async {
  final db = await ref.watch(localDatabaseProvider.future);
  return loadIdentity(db);
});

/// The local event log of the current user.
final eventLogProvider = FutureProvider<EventLog>((ref) async {
  final db = await ref.watch(localDatabaseProvider.future);
  final identity = await ref.watch(identityProvider.future);
  return DriftEventLog(db, identity, appVersion: appVersion);
});

/// Opens the event log of any profile on this device, as sync needs for
/// profiles not in use.
final profileLogsProvider = FutureProvider<EventLog Function(String profileId)>(
  (ref) async {
    final db = await ref.watch(localDatabaseProvider.future);
    final identity = await ref.watch(identityProvider.future);
    return (String profileId) => DriftEventLog(
      db,
      LocalIdentity(deviceId: identity.deviceId, userId: profileId),
      appVersion: appVersion,
    );
  },
);

/// The current user's settings.
final settingsStoreProvider = FutureProvider<SettingsStore>((ref) async {
  final db = await ref.watch(localDatabaseProvider.future);
  final identity = await ref.watch(identityProvider.future);
  return DriftSettingsStore(db, identity.userId);
});

/// The profiles on this device (AGENTS.md §10).
final accountStoreProvider = FutureProvider<AccountStore>(
  (ref) async =>
      DriftAccountStore(await ref.watch(localDatabaseProvider.future)),
);

/// Reads the current user's wallet (AGENTS.md §5.8).
final walletRepositoryProvider = FutureProvider<WalletRepository>((ref) async {
  final log = await ref.watch(eventLogProvider.future);
  final accounts = await ref.watch(accountStoreProvider.future);
  return LocalWalletRepository(
    log,
    confirmed: () async =>
        (await accounts.profile(log.identity.userId))?.confirmedBalance,
  );
});

/// The current user's wallet. Whatever moves coins refreshes it with
/// `ref.invalidate(walletProvider)`.
final walletProvider = FutureProvider<Wallet>((ref) async {
  final repository = await ref.watch(walletRepositoryProvider.future);
  return repository.load();
});
