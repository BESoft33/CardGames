import 'dart:convert';

import 'package:cardgames_server/cardgames_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A user as Supabase Auth returns it, with a linked Google identity. An
/// identity's `id` is the provider's ID: Google's subject.
const Map<String, Object?> googleUser = {
  'id': '6e1b1a4e-0000-4000-8000-000000000001',
  'aud': 'authenticated',
  'role': 'authenticated',
  'is_anonymous': false,
  'identities': [
    {
      'identity_id': '9a9b0c0d-0000-4000-8000-000000000002',
      'id': '108246813579246813579',
      'user_id': '6e1b1a4e-0000-4000-8000-000000000001',
      'provider': 'google',
      'identity_data': {'sub': '108246813579246813579'},
    },
  ],
};

void main() {
  test('reads the account and its Google subject', () {
    final user = SupabaseTokenVerifier.parseUser(googleUser)!;
    expect(user.id, googleUser['id']);
    expect(user.isAnonymous, isFalse);
    expect(user.googleSubject, '108246813579246813579');
    final guest = SupabaseTokenVerifier.parseUser({
      'id': 'g',
      'is_anonymous': true,
      'identities': <Object?>[],
    })!;
    expect((guest.isAnonymous, guest.googleSubject), (true, null));
    expect(SupabaseTokenVerifier.parseUser({'msg': 'nope'}), isNull);
  });

  test('asks Supabase Auth once per token and minute', () async {
    var calls = 0;
    var now = DateTime.utc(2026, 10, 9);
    final verifier = SupabaseTokenVerifier(
      supabaseUrl: Uri.parse('https://example.supabase.co'),
      apiKey: 'publishable',
      clock: () => now,
      client: MockClient((request) async {
        calls++;
        expect(
          request.url.toString(),
          'https://example.supabase.co/auth/v1/user',
        );
        expect(request.headers['apikey'], 'publishable');
        return request.headers['Authorization'] == 'Bearer good'
            ? http.Response(jsonEncode(googleUser), 200)
            : http.Response('{"code":403}', 403);
      }),
    );
    expect((await verifier.verify('good'))!.googleSubject, isNotNull);
    expect(await verifier.verify('good'), isNotNull);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 2));
    await verifier.verify('good');
    expect(calls, 2);
    expect(await verifier.verify('bad'), isNull);
  });
}
