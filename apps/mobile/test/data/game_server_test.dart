import 'dart:io';

import 'package:card_games/data/remote/game_server.dart';
import 'package:cardgames_server/cardgames_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:sync_protocol/sync_protocol.dart';

/// Hands [request] to the real server's [handler], in memory, as the
/// network would.
Future<http.Response> forward(
  shelf.Handler handler,
  http.Request request,
) async {
  final response = await handler(
    shelf.Request(
      request.method,
      request.url,
      headers: request.headers,
      body: request.bodyBytes,
    ),
  );
  final body = <int>[];
  await for (final chunk in response.read()) {
    body.addAll(chunk);
  }
  return http.Response.bytes(
    body,
    response.statusCode,
    headers: response.headers,
  );
}

/// An HTTP client wired to the real server's [handler].
http.Client wiredTo(shelf.Handler handler) =>
    MockClient((request) => forward(handler, request));

void main() {
  final handler = buildHandler(
    service: SyncService(store: MemoryStore()),
    verifier: FakeTokenVerifier({
      'token': const AuthUser(id: 'guest', isAnonymous: true),
    }),
  );
  final base = Uri.parse('https://server.example.com');

  test('talks to the real server over JSON, uploads gzipped', () async {
    var gzipped = false;
    final server = HttpGameServer(
      base,
      client: MockClient((request) async {
        gzipped =
            gzipped ||
            request.headers[HttpHeaders.contentEncodingHeader] == 'gzip';
        return forward(handler, request);
      }),
    );
    expect((await server.wallet('token')).balance, 1000);
    final event = EventEnvelope.next(
      eventId: uuidV7(),
      matchId: uuidV7(),
      seq: 0,
      type: EventTypes.matchCreated,
      actor: Actors.user,
      payload: const {'stake': 0},
      clientTime: DateTime.utc(2026, 10, 9),
      userId: uuidV7(),
      deviceId: uuidV7(),
      gameId: 'twentynine',
      rulesVersion: 1,
      appVersion: 'test',
      prevHash: genesisHash,
    );
    final ack = await server.upload(
      UploadBatch(matchId: event.matchId, events: [event]),
      'token',
    );
    expect(gzipped, isTrue);
    expect(ack.status, MatchSyncStatus.rejected, reason: 'no rules, no seats');
    expect(ack.ackedSeq, 0, reason: 'kept, with the flag');
  });

  test('a refusal and an outage are told apart', () async {
    final server = HttpGameServer(base, client: wiredTo(handler));
    await expectLater(
      server.wallet('stolen'),
      throwsA(
        isA<ServerRefused>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.code, 'code', ApiErrors.unauthorized),
      ),
    );
    final down = HttpGameServer(
      base,
      client: MockClient((_) async => throw http.ClientException('no route')),
    );
    await expectLater(down.wallet('token'), throwsA(isA<ServerUnavailable>()));
    final failing = HttpGameServer(
      base,
      client: MockClient(
        (_) async => http.Response('{"error":"internal"}', 500),
      ),
    );
    await expectLater(
      failing.wallet('token'),
      throwsA(isA<ServerUnavailable>()),
    );
    final garbled = HttpGameServer(
      base,
      client: MockClient((_) async => http.Response('<html>', 502)),
    );
    await expectLater(
      garbled.wallet('token'),
      throwsA(isA<ServerUnavailable>()),
    );
  });

  test('only HTTPS is allowed (AGENTS.md §12)', () {
    expect(
      () => HttpGameServer(Uri.parse('http://server.example.com')),
      throwsArgumentError,
    );
  });
}
