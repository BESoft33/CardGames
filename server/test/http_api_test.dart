import 'dart:convert';
import 'dart:io';

import 'package:cardgames_server/cardgames_server.dart';
import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const AuthUser guest = AuthUser(id: 'guest-a', isAnonymous: true);
const AuthUser signedIn = AuthUser(
  id: 'user-g',
  isAnonymous: false,
  googleSubject: '42',
);

void main() {
  late Handler handler;
  late MemoryStore store;

  setUp(() {
    store = MemoryStore();
    handler = buildHandler(
      service: SyncService(store: store),
      verifier: FakeTokenVerifier({
        'guest-token': guest,
        'google-token': signedIn,
      }),
    );
  });

  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, {
    String? token,
    Object? body,
    bool gzipped = false,
  }) async {
    final bytes = body == null ? null : utf8.encode(jsonEncode(body));
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          if (gzipped) 'Content-Encoding': 'gzip',
          'Content-Type': 'application/json',
        },
        body: bytes == null ? null : (gzipped ? gzip.encode(bytes) : bytes),
      ),
    );
    final text = await response.readAsString();
    return (
      response.statusCode,
      text.startsWith('{')
          ? jsonDecode(text) as Map<String, Object?>
          : {'text': text},
    );
  }

  test('answers health checks without a token', () async {
    final (status, body) = await call('GET', ServerApi.health);
    expect((status, body['text']), (200, 'ok'));
  });

  test('refuses requests without a valid token', () async {
    final (status, body) = await call('GET', ServerApi.wallet);
    expect((status, body['error']), (401, ApiErrors.unauthorized));
    expect((await call('GET', ServerApi.wallet, token: 'stolen')).$1, 401);
  });

  test('a compressed upload is acknowledged', () async {
    final events = chain(playMatch(seed: 2));
    final batch = UploadBatch(
      matchId: events.first.matchId,
      events: events.take(40).toList(),
    );
    final (status, body) = await call(
      'POST',
      ServerApi.sync,
      token: 'guest-token',
      body: batch.toJson(),
      gzipped: true,
    );
    expect(status, 200);
    final ack = SyncAck.fromJson(body);
    expect(ack.ackedSeq, 39);
    expect(ack.status, MatchSyncStatus.open);
    expect(ack.wallet.balance, 1000);
  });

  test('the wallet pays the sign-up bonus once', () async {
    final (_, first) = await call(
      'GET',
      ServerApi.wallet,
      token: 'google-token',
    );
    expect(WalletState.fromJson(first).balance, 3500);
    final (_, second) = await call(
      'GET',
      ServerApi.wallet,
      token: 'google-token',
    );
    expect(WalletState.fromJson(second).credited, isEmpty);
  });

  test('a guest merges into the signed-in account with its token', () async {
    await call('GET', ServerApi.wallet, token: 'guest-token');
    final (status, body) = await call(
      'POST',
      ServerApi.merge,
      token: 'google-token',
      body: const MergeRequest(guestAccessToken: 'guest-token').toJson(),
    );
    expect(status, 200);
    expect(MergeResult.fromJson(body).coinsMoved, 0);
    final (refused, error) = await call(
      'GET',
      ServerApi.wallet,
      token: 'guest-token',
    );
    expect((refused, error['error']), (403, ApiErrors.mergedAccount));
    final (badGuest, _) = await call(
      'POST',
      ServerApi.merge,
      token: 'google-token',
      body: const MergeRequest(guestAccessToken: 'nobody').toJson(),
    );
    expect(badGuest, 400);
  });

  test('malformed, oversized and unknown requests are refused', () async {
    final (malformed, body) = await call(
      'POST',
      ServerApi.sync,
      token: 'guest-token',
      body: {'matchId': 'm'},
    );
    expect((malformed, body['error']), (400, ApiErrors.badRequest));
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost${ServerApi.sync}'),
        headers: {'Authorization': 'Bearer guest-token'},
        body: List.filled(maxBodyBytes + 1, 32),
      ),
    );
    expect(response.statusCode, 413);
    final gzipBomb = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost${ServerApi.sync}'),
        headers: {
          'Authorization': 'Bearer guest-token',
          'Content-Encoding': 'gzip',
        },
        body: [1, 2, 3],
      ),
    );
    expect(gzipBomb.statusCode, 400);
    expect((await call('GET', '/nowhere')).$1, 404);
  });
}
