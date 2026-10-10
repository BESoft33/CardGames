import 'package:drift/drift.dart';

import 'local_database.dart';

/// Where one user's choices, such as the table fee, are kept. Values are
/// text; each setting parses its own and falls back to its default.
abstract interface class SettingsStore {
  /// The value saved under [key], or null if there is none.
  Future<String?> read(String key);

  /// Saves [value] under [key], replacing any earlier value.
  Future<void> write(String key, String value);
}

/// The settings of [userId] in the encrypted local database.
final class DriftSettingsStore implements SettingsStore {
  /// A store in [_db] for [userId].
  DriftSettingsStore(this._db, this.userId);

  final LocalDatabase _db;

  /// Whose settings these are.
  final String userId;

  @override
  Future<String?> read(String key) async {
    final row =
        await (_db.select(_db.settings)
              ..where((s) => s.userId.equals(userId) & s.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(userId: userId, key: key, value: value),
      );
}

/// Settings kept in memory, for tests.
final class MemorySettingsStore implements SettingsStore {
  /// A store holding [values].
  MemorySettingsStore([Map<String, String>? values]) : values = values ?? {};

  /// The saved values by key.
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
