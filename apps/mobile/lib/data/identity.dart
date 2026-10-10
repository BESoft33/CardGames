import 'package:drift/drift.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'local_database.dart';

/// Who and where the app is recording for: this device, and the profile its
/// events belong to.
final class LocalIdentity {
  /// Creates an identity.
  const LocalIdentity({required this.deviceId, required this.userId});

  /// A random ID made on this device's first launch.
  final String deviceId;

  /// The profile in use: a guest made on first launch, or a signed-in
  /// account (AGENTS.md §10). Events are kept apart by it.
  final String userId;
}

/// A profile on this device (AGENTS.md §10).
final class LocalProfile {
  /// Creates a profile.
  const LocalProfile({
    required this.profileId,
    required this.kind,
    this.remoteUserId,
    this.displayName,
    this.confirmedBalance,
  });

  /// Its ID: the `userId` of the events it logs.
  final String profileId;

  /// A guest, or signed in with Google.
  final ProfileKind kind;

  /// The Supabase user it is bound to, once it has gone online.
  final String? remoteUserId;

  /// The name to show for a signed-in account.
  final String? displayName;

  /// The balance the server last confirmed, or null before the first sync.
  final int? confirmedBalance;

  /// Whether this is a guest.
  bool get isGuest => kind == ProfileKind.guest;

  /// A copy with the given fields changed.
  LocalProfile copyWith({
    ProfileKind? kind,
    String? remoteUserId,
    String? displayName,
    int? confirmedBalance,
  }) => LocalProfile(
    profileId: profileId,
    kind: kind ?? this.kind,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    displayName: displayName ?? this.displayName,
    confirmedBalance: confirmedBalance ?? this.confirmedBalance,
  );
}

Future<String?> _meta(LocalDatabase db, String key) async => (await (db.select(
  db.meta,
)..where((meta) => meta.key.equals(key))).getSingleOrNull())?.value;

Future<void> _setMeta(LocalDatabase db, String key, String value) => db
    .into(db.meta)
    .insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

/// Reads the device ID and the profile in use. On first launch it makes
/// both: the profile is a new guest (AGENTS.md §10).
Future<LocalIdentity> loadIdentity(LocalDatabase db) =>
    db.transaction(() async {
      var deviceId = await _meta(db, 'device_id');
      if (deviceId == null) {
        deviceId = uuidV7();
        await _setMeta(db, 'device_id', deviceId);
      }
      var active = await _meta(db, 'active_profile_id');
      if (active == null) {
        active = uuidV7();
        await DriftAccountStore(db)._insertGuest(active);
        await _setMeta(db, 'active_profile_id', active);
      }
      return LocalIdentity(deviceId: deviceId, userId: active);
    });

/// The profiles on this device, and which is in use.
abstract interface class AccountStore {
  /// The profile in use.
  Future<LocalProfile> active();

  /// The profile with [profileId], if any.
  Future<LocalProfile?> profile(String profileId);

  /// The profile bound to the Supabase user [remoteUserId], if any.
  Future<LocalProfile?> byRemoteUser(String remoteUserId);

  /// Every profile, oldest first.
  Future<List<LocalProfile>> all();

  /// Makes [profileId] the profile in use.
  Future<void> setActive(String profileId);

  /// Makes a new guest profile, not yet in use.
  Future<LocalProfile> newGuest();

  /// Saves [profile], which must exist.
  Future<void> save(LocalProfile profile);
}

/// The profiles in the encrypted local database.
final class DriftAccountStore implements AccountStore {
  /// A store in [_db].
  DriftAccountStore(this._db);

  final LocalDatabase _db;

  static LocalProfile _profile(ProfileRow row) => LocalProfile(
    profileId: row.profileId,
    kind: row.kind,
    remoteUserId: row.remoteUserId,
    displayName: row.displayName,
    confirmedBalance: row.confirmedBalance,
  );

  Future<void> _insertGuest(String profileId) => _db
      .into(_db.profiles)
      .insert(
        ProfilesCompanion.insert(
          profileId: profileId,
          kind: ProfileKind.guest,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  @override
  Future<LocalProfile> active() async {
    final identity = await loadIdentity(_db);
    return (await profile(identity.userId))!;
  }

  @override
  Future<LocalProfile?> profile(String profileId) async {
    final row = await (_db.select(
      _db.profiles,
    )..where((p) => p.profileId.equals(profileId))).getSingleOrNull();
    return row == null ? null : _profile(row);
  }

  @override
  Future<LocalProfile?> byRemoteUser(String remoteUserId) async {
    final rows =
        await (_db.select(_db.profiles)
              ..where((p) => p.remoteUserId.equals(remoteUserId))
              ..orderBy([(p) => OrderingTerm(expression: p.createdAt)]))
            .get();
    return rows.isEmpty ? null : _profile(rows.first);
  }

  @override
  Future<List<LocalProfile>> all() async => [
    for (final row in await (_db.select(
      _db.profiles,
    )..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).get())
      _profile(row),
  ];

  @override
  Future<void> setActive(String profileId) =>
      _setMeta(_db, 'active_profile_id', profileId);

  @override
  Future<LocalProfile> newGuest() async {
    final id = uuidV7();
    await _insertGuest(id);
    return (await profile(id))!;
  }

  @override
  Future<void> save(LocalProfile profile) async {
    await (_db.update(
      _db.profiles,
    )..where((p) => p.profileId.equals(profile.profileId))).write(
      ProfilesCompanion(
        kind: Value(profile.kind),
        remoteUserId: Value(profile.remoteUserId),
        displayName: Value(profile.displayName),
        confirmedBalance: Value(profile.confirmedBalance),
      ),
    );
  }
}

/// Profiles kept in memory, for tests. Starts with one guest in use.
final class MemoryAccountStore implements AccountStore {
  /// A store whose first guest has [guestId].
  MemoryAccountStore({String guestId = 'user'}) : _active = guestId {
    _profiles[guestId] = LocalProfile(
      profileId: guestId,
      kind: ProfileKind.guest,
    );
  }

  final Map<String, LocalProfile> _profiles = {};
  String _active;

  @override
  Future<LocalProfile> active() async => _profiles[_active]!;

  @override
  Future<LocalProfile?> profile(String profileId) async => _profiles[profileId];

  @override
  Future<LocalProfile?> byRemoteUser(String remoteUserId) async {
    for (final profile in _profiles.values) {
      if (profile.remoteUserId == remoteUserId) return profile;
    }
    return null;
  }

  @override
  Future<List<LocalProfile>> all() async => _profiles.values.toList();

  @override
  Future<void> setActive(String profileId) async {
    if (!_profiles.containsKey(profileId)) {
      throw StateError('No profile $profileId');
    }
    _active = profileId;
  }

  @override
  Future<LocalProfile> newGuest() async {
    final id = uuidV7();
    return _profiles[id] = LocalProfile(profileId: id, kind: ProfileKind.guest);
  }

  @override
  Future<void> save(LocalProfile profile) async {
    if (!_profiles.containsKey(profile.profileId)) {
      throw StateError('No profile ${profile.profileId}');
    }
    _profiles[profile.profileId] = profile;
  }
}
