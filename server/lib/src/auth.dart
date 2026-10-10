import 'dart:convert';

import 'package:http/http.dart' as http;

/// A Supabase account, as the server needs to know it.
final class AuthUser {
  /// Creates an account.
  const AuthUser({
    required this.id,
    required this.isAnonymous,
    this.googleSubject,
  });

  /// The Supabase user ID.
  final String id;

  /// Whether this is a guest made by anonymous sign-in (AGENTS.md §10).
  final bool isAnonymous;

  /// The Google account's subject ID, if a Google identity is linked. Used
  /// only, hashed, to pay the sign-up bonus once (docs/decisions.md D-032).
  final String? googleSubject;
}

/// Finds the account an access token belongs to.
abstract interface class TokenVerifier {
  /// The account of [accessToken], or null if the token is not valid.
  Future<AuthUser?> verify(String accessToken);
}

/// Asks Supabase Auth who a token belongs to (`GET /auth/v1/user`), which
/// also checks that the token is valid and not revoked.
final class SupabaseTokenVerifier implements TokenVerifier {
  /// A verifier for the project at [supabaseUrl], calling it with the
  /// project's publishable [apiKey].
  SupabaseTokenVerifier({
    required Uri supabaseUrl,
    required this.apiKey,
    http.Client? client,
    this.cacheFor = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _userUrl = supabaseUrl.resolve('auth/v1/user'),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Uri _userUrl;
  final http.Client _client;
  final DateTime Function() _clock;

  /// The project's publishable (anon) key.
  final String apiKey;

  /// How long an answer is reused for the same token.
  final Duration cacheFor;

  final Map<String, (DateTime, AuthUser)> _cache = {};

  @override
  Future<AuthUser?> verify(String accessToken) async {
    final now = _clock();
    final cached = _cache[accessToken];
    if (cached != null && now.difference(cached.$1) < cacheFor) {
      return cached.$2;
    }
    final response = await _client.get(
      _userUrl,
      headers: {'apikey': apiKey, 'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return null;
    final user = parseUser(jsonDecode(response.body));
    if (user == null) return null;
    if (_cache.length > 10000) _cache.clear();
    _cache[accessToken] = (now, user);
    return user;
  }

  /// Reads the user object of Supabase Auth. Returns null if it is not one.
  static AuthUser? parseUser(Object? json) {
    if (json case {'id': final String id}) {
      String? google;
      if (json['identities'] case final List<Object?> identities) {
        for (final identity in identities) {
          if (identity case {'provider': 'google', 'id': final String subject}
              when subject.isNotEmpty) {
            google = subject;
          }
        }
      }
      return AuthUser(
        id: id,
        isAnonymous: json['is_anonymous'] == true,
        googleSubject: google,
      );
    }
    return null;
  }
}

/// A verifier that knows a fixed set of tokens, for tests.
final class FakeTokenVerifier implements TokenVerifier {
  /// A verifier accepting the tokens in [users].
  FakeTokenVerifier([Map<String, AuthUser>? users]) : users = users ?? {};

  /// The accounts by token.
  final Map<String, AuthUser> users;

  @override
  Future<AuthUser?> verify(String accessToken) async => users[accessToken];
}
