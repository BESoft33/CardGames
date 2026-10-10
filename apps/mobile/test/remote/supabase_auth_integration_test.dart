import 'dart:convert';
import 'dart:io';

import 'package:card_games/data/remote/auth_repository.dart';
import 'package:card_games/data/remote/google_identity.dart';
import 'package:card_games/data/remote/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';
import 'package:sync_protocol/sync_protocol.dart';

/// Runs the app's Supabase accounts against a local Supabase stack, with
/// the real `gotrue` client. `tool/backend_check.sh` sets the variables;
/// without them the tests are skipped. Google sign-in needs real Google
/// accounts and is not tested here.
final String? supabaseUrl = Platform.environment['CARDGAMES_TEST_SUPABASE_URL'];
final String? supabaseKey = Platform.environment['CARDGAMES_TEST_SUPABASE_KEY'];

void main() {
  final skip = supabaseUrl == null || supabaseKey == null
      ? 'needs a local Supabase stack; run tool/backend_check.sh'
      : null;
  late MemorySessionStore sessions;
  late SupabaseAuthRepository auth;

  SupabaseAuthRepository repository(String url) => SupabaseAuthRepository(
    supabaseUrl: url,
    supabaseKey: supabaseKey ?? '',
    sessions: sessions,
    google: const NoGoogleIdentity(),
  );

  setUp(() {
    sessions = MemorySessionStore();
    auth = repository(supabaseUrl ?? '');
  });

  test('a guest goes online with an anonymous account', () async {
    final guest = await auth.signInAsGuest();
    expect(isUuid(guest.userId), isTrue);
    expect(guest.isAnonymous, isTrue);
    expect(sessions.sessions.keys, [guest.userId]);
    final again = await auth.session(guest.userId);
    expect(again!.userId, guest.userId);
  }, skip: skip);

  test('signing out revokes the session and deletes it', () async {
    final guest = await auth.signInAsGuest();
    final saved =
        jsonDecode(sessions.sessions[guest.userId]!) as Map<String, Object?>;
    final refreshToken = saved['refresh_token']! as String;
    await auth.signOut(guest.userId);
    expect(sessions.sessions, isEmpty);
    expect(await auth.session(guest.userId), isNull);
    // The server no longer accepts the session's refresh token.
    final client = GoTrueClient(
      url: '$supabaseUrl/auth/v1',
      headers: {'apikey': supabaseKey!},
      autoRefreshToken: false,
    );
    addTearDown(client.dispose);
    await expectLater(
      client.refreshSession(refreshToken),
      throwsA(isA<AuthException>()),
    );
  }, skip: skip);

  test(
    'out of reach, a saved session still plays and nothing is lost',
    () async {
      final guest = await auth.signInAsGuest();
      final saved = sessions.sessions[guest.userId];
      final unreachable = repository('http://127.0.0.1:9');
      // A session that has not expired needs no network (AGENTS.md §10).
      expect((await unreachable.session(guest.userId))!.userId, guest.userId);
      await expectLater(
        unreachable.signInAsGuest(),
        throwsA(isA<AuthUnavailable>()),
      );
      expect(sessions.sessions[guest.userId], saved);
    },
    skip: skip,
  );
}
