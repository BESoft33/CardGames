import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'local_database.dart';

/// Where the key of the local database is kept.
abstract interface class DatabaseKeyStore {
  /// The database key: 64 hex digits (256 bits). Made on first use.
  Future<String> databaseKey();
}

final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

/// A fresh random 256-bit key as 64 hex digits.
String newDatabaseKey([math.Random? random]) {
  final source = random ?? math.Random.secure();
  return [
    for (var i = 0; i < 32; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Keeps the database key in the Keychain or the Android Keystore
/// (AGENTS.md §12). On iOS the key never leaves this device, so a backup of
/// the database file could not be read anywhere else.
final class SecureDatabaseKeyStore implements DatabaseKeyStore {
  /// Uses the given secure storage, or the platform's.
  const SecureDatabaseKeyStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;

  static const String _name = 'local_database_key_v1';

  @override
  Future<String> databaseKey() async {
    final existing = await _storage.read(key: _name);
    if (existing != null && _keyPattern.hasMatch(existing)) return existing;
    final key = newDatabaseKey();
    await _storage.write(key: _name, value: key);
    return key;
  }
}

/// Unlocks a freshly opened database with [key].
///
/// Throws a [StateError] if SQLite was built without encryption or [key] is
/// not 64 hex digits; then the data would not be protected.
void unlockDatabase(Database database, String key) {
  if (database.select('PRAGMA cipher;').isEmpty) {
    throw StateError('This SQLite build cannot encrypt databases');
  }
  if (!_keyPattern.hasMatch(key)) {
    throw ArgumentError('The database key must be 64 hex digits');
  }
  database.execute("PRAGMA key = '$key';");
}

/// Whether the database in [file], if any, opens with [key].
bool opensWithKey(File file, String key) {
  if (!file.existsSync()) return true;
  final database = sqlite3.open(file.path);
  try {
    unlockDatabase(database, key);
    database.select('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    database.close();
  }
}

/// Opens the encrypted local database in the app's private folder.
///
/// If the file cannot be read with the stored key, for example because the
/// key was lost, it is set aside under a new name and a fresh database is
/// started: the old data could not be decrypted anyway.
Future<LocalDatabase> openLocalDatabase(DatabaseKeyStore keys) async {
  final key = await keys.databaseKey();
  final folder = await getApplicationSupportDirectory();
  final file = File(p.join(folder.path, 'cardgames.db'));
  if (!opensWithKey(file, key)) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await file.rename('${file.path}.unreadable-$stamp');
  }
  return LocalDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (database) => unlockDatabase(database, key),
    ),
  );
}
