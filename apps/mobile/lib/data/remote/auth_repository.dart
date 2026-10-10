import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';

import 'google_identity.dart';
import 'session_store.dart';

/// A Supabase account, with an access token that is valid now.
typedef RemoteSession = ({String userId, String accessToken, bool isAnonymous});

/// How a Google sign-in ended.
sealed class GoogleSignInResult {
  const GoogleSignInResult();
}

/// The Google account was new: it now belongs to the guest's own account,
/// which keeps its coins and its user ID (AGENTS.md §10).
final class GoogleLinked extends GoogleSignInResult {
  /// Creates the result.
  const GoogleLinked(this.session, this.displayName);

  /// The guest's account, now signed in with Google.
  final RemoteSession session;

  /// The Google account's name.
  final String? displayName;
}

/// The Google account already had a profile: the player is now signed in
/// to it, and the guest's progress has to be merged into it.
final class GoogleSwitched extends GoogleSignInResult {
  /// Creates the result.
  const GoogleSwitched(this.session, this.displayName);

  /// The existing account.
  final RemoteSession session;

  /// The Google account's name.
  final String? displayName;
}

/// The player closed the Google sign-in.
final class GoogleCancelled extends GoogleSignInResult {
  /// Creates the result.
  const GoogleCancelled();
}

/// Supabase Auth could not be reached; try again later.
final class AuthUnavailable implements Exception {
  /// Creates the failure.
  const AuthUnavailable([this.detail = '']);

  /// What happened, for developers.
  final String detail;

  @override
  String toString() => 'AuthUnavailable($detail)';
}

/// Accounts: the silent guest account, Google sign-in and sign-out
/// (AGENTS.md §10). Other providers, such as Sign in with Apple, fit behind
/// the same interface.
abstract interface class AuthRepository {
  /// Creates an anonymous account for a guest going online for the first
  /// time.
  Future<RemoteSession> signInAsGuest();

  /// The saved session of [userId], refreshed if it had expired. Null if
  /// there is none, or the server no longer accepts it.
  ///
  /// Throws [AuthUnavailable] if a refresh was needed but Auth could not be
  /// reached; the session is kept for later.
  Future<RemoteSession?> session(String userId);

  /// Signs in with Google. A new Google account is linked to the guest
  /// [guestUserId], who keeps everything; an existing one is signed in to
  /// instead.
  Future<GoogleSignInResult> signInWithGoogle({required String guestUserId});

  /// Revokes the session of [userId] where possible, and deletes its
  /// tokens from this device.
  Future<void> signOut(String userId);
}

/// Accounts on Supabase Auth, through the pure-Dart `gotrue` client.
/// Sessions are saved per account in [sessions], which is secure storage.
final class SupabaseAuthRepository implements AuthRepository {
  /// Creates the repository for the project at [supabaseUrl].
  SupabaseAuthRepository({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.sessions,
    required this.google,
    http.Client? client,
  }) : _http = client;

  /// The Supabase project's URL.
  final String supabaseUrl;

  /// The project's publishable key.
  final String supabaseKey;

  /// Where sessions are saved.
  final SessionStore sessions;

  /// Native Google sign-in.
  final GoogleIdentitySource google;

  final http.Client? _http;

  GoTrueClient _client() => GoTrueClient(
    url: '$supabaseUrl/auth/v1',
    headers: {'apikey': supabaseKey, 'Authorization': 'Bearer $supabaseKey'},
    autoRefreshToken: false,
    httpClient: _http,
  );

  /// Runs [body] with a fresh client, turning network failures into
  /// [AuthUnavailable].
  Future<T> _with<T>(Future<T> Function(GoTrueClient client) body) async {
    final client = _client();
    try {
      return await body(client);
    } on AuthRetryableFetchException catch (error) {
      throw AuthUnavailable(error.message);
    } on SocketException catch (error) {
      throw AuthUnavailable(error.message);
    } on http.ClientException catch (error) {
      throw AuthUnavailable(error.message);
    } on TimeoutException {
      throw const AuthUnavailable('timed out');
    } finally {
      client.dispose();
    }
  }

  Future<RemoteSession> _save(Session? session) async {
    if (session == null) throw const AuthException('Supabase gave no session');
    await sessions.write(session.user.id, jsonEncode(session.toJson()));
    return (
      userId: session.user.id,
      accessToken: session.accessToken,
      isAnonymous: session.user.isAnonymous,
    );
  }

  @override
  Future<RemoteSession> signInAsGuest() => _with(
    (client) async => _save((await client.signInAnonymously()).session),
  );

  @override
  Future<RemoteSession?> session(String userId) async {
    final saved = await sessions.read(userId);
    if (saved == null) return null;
    return _with((client) async {
      try {
        return await _save((await client.recoverSession(saved)).session);
      } on AuthRetryableFetchException {
        rethrow;
      } on AuthException {
        // The server refused the refresh token: it will never work again.
        await sessions.delete(userId);
        return null;
      }
    });
  }

  @override
  Future<GoogleSignInResult> signInWithGoogle({
    required String guestUserId,
  }) async {
    final identity = await google.signIn();
    if (identity == null) return const GoogleCancelled();
    final saved = await sessions.read(guestUserId);
    return _with((client) async {
      if (saved != null) {
        await client.recoverSession(saved);
        try {
          final linked = await client.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: identity.idToken,
            accessToken: identity.accessToken,
          );
          return GoogleLinked(
            await _save(linked.session),
            identity.displayName,
          );
        } on AuthException catch (error) {
          if (error.code != ErrorCode.identityAlreadyExists.code) rethrow;
        }
      }
      final other = _client();
      try {
        final signedIn = await other.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: identity.idToken,
          accessToken: identity.accessToken,
        );
        return GoogleSwitched(
          await _save(signedIn.session),
          identity.displayName,
        );
      } finally {
        other.dispose();
      }
    });
  }

  @override
  Future<void> signOut(String userId) async {
    final saved = await sessions.read(userId);
    if (saved != null) {
      try {
        await _with((client) async {
          await client.recoverSession(saved);
          await client.signOut();
        });
      } on AuthUnavailable {
        // Offline: the session cannot be revoked now. Its tokens are still
        // deleted from this device, which is the only place they were.
      } on AuthException {
        // Already invalid on the server.
      }
    }
    await sessions.delete(userId);
    try {
      await google.signOut();
    } on Exception {
      // Not signed in to Google on this device.
    }
  }
}

/// Accounts kept in memory, for tests. Tokens are `token-<user ID>`.
final class FakeAuthRepository implements AuthRepository {
  /// The accounts by token, as the game server would see them.
  final Map<String, ({String id, bool isAnonymous, String? googleSubject})>
  accounts = {};

  /// Which account each Google subject belongs to.
  final Map<String, String> googleAccounts = {};

  /// The Google subject the next sign-in chooses; null cancels it.
  String? nextGoogleSubject;

  /// The name of the Google account chosen.
  String? nextGoogleName = 'Test Player';

  /// Whether Auth answers; when false every call throws [AuthUnavailable].
  bool online = true;

  /// Accounts signed out, in order.
  final List<String> signedOut = [];

  void _check() {
    if (!online) throw const AuthUnavailable('offline');
  }

  RemoteSession _session(String id) {
    final account = accounts['token-$id']!;
    return (
      userId: id,
      accessToken: 'token-$id',
      isAnonymous: account.isAnonymous,
    );
  }

  @override
  Future<RemoteSession> signInAsGuest() async {
    _check();
    final id = uuidV7();
    accounts['token-$id'] = (id: id, isAnonymous: true, googleSubject: null);
    return _session(id);
  }

  @override
  Future<RemoteSession?> session(String userId) async {
    if (!accounts.containsKey('token-$userId') || signedOut.contains(userId)) {
      return null;
    }
    _check();
    return _session(userId);
  }

  @override
  Future<GoogleSignInResult> signInWithGoogle({
    required String guestUserId,
  }) async {
    _check();
    final subject = nextGoogleSubject;
    if (subject == null) return const GoogleCancelled();
    final existing = googleAccounts[subject];
    if (existing == null && accounts.containsKey('token-$guestUserId')) {
      googleAccounts[subject] = guestUserId;
      accounts['token-$guestUserId'] = (
        id: guestUserId,
        isAnonymous: false,
        googleSubject: subject,
      );
      return GoogleLinked(_session(guestUserId), nextGoogleName);
    }
    final id = existing ?? uuidV7();
    googleAccounts[subject] = id;
    accounts['token-$id'] = (
      id: id,
      isAnonymous: false,
      googleSubject: subject,
    );
    signedOut.remove(id);
    return GoogleSwitched(_session(id), nextGoogleName);
  }

  @override
  Future<void> signOut(String userId) async => signedOut.add(userId);
}
