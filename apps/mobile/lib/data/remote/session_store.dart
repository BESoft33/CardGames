import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where Supabase sessions are kept, one per account. They hold the access
/// and refresh tokens, so they live only in secure storage, never in
/// preferences, files or logs (AGENTS.md §12).
abstract interface class SessionStore {
  /// The saved session of [userId], as JSON, or null.
  Future<String?> read(String userId);

  /// Saves [session], as JSON, for [userId].
  Future<void> write(String userId, String session);

  /// Deletes the session of [userId].
  Future<void> delete(String userId);
}

/// Sessions in the Keychain or the Android Keystore, readable on this
/// device only.
final class SecureSessionStore implements SessionStore {
  /// Uses the given secure storage, or the platform's.
  const SecureSessionStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;

  static String _key(String userId) => 'supabase_session_$userId';

  @override
  Future<String?> read(String userId) => _storage.read(key: _key(userId));

  @override
  Future<void> write(String userId, String session) =>
      _storage.write(key: _key(userId), value: session);

  @override
  Future<void> delete(String userId) => _storage.delete(key: _key(userId));
}

/// Sessions in memory, for tests.
final class MemorySessionStore implements SessionStore {
  /// The saved sessions by account.
  final Map<String, String> sessions = {};

  @override
  Future<String?> read(String userId) async => sessions[userId];

  @override
  Future<void> write(String userId, String session) async =>
      sessions[userId] = session;

  @override
  Future<void> delete(String userId) async => sessions.remove(userId);
}
