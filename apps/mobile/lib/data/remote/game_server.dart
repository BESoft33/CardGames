import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';

/// The game server could not be reached, or failed; try again later.
final class ServerUnavailable implements Exception {
  /// Creates the failure.
  const ServerUnavailable([this.detail = '']);

  /// What happened, for developers.
  final String detail;

  @override
  String toString() => 'ServerUnavailable($detail)';
}

/// The game server refused a request.
final class ServerRefused implements Exception {
  /// Creates the refusal.
  const ServerRefused(this.status, this.code, [this.message = '']);

  /// The HTTP status.
  final int status;

  /// One of [ApiErrors], or another code.
  final String code;

  /// What went wrong, for developers.
  final String message;

  @override
  String toString() => 'ServerRefused($status, $code, $message)';
}

/// The game server's API ([ServerApi]), as the app uses it.
abstract interface class GameServer {
  /// Uploads one batch of a match's events.
  Future<SyncAck> upload(UploadBatch batch, String accessToken);

  /// The player's confirmed coins; pays any one-off bonus that is due.
  Future<WalletState> wallet(String accessToken);

  /// Moves the guest with [guestAccessToken] into the account of
  /// [accessToken].
  Future<MergeResult> merge(String guestAccessToken, String accessToken);
}

/// The game server over HTTPS. Uploads are gzip-compressed (AGENTS.md §9).
final class HttpGameServer implements GameServer {
  /// A client of the server at [baseUrl], which must be HTTPS unless
  /// [allowInsecure], for tests only (AGENTS.md §12).
  HttpGameServer(
    this.baseUrl, {
    http.Client? client,
    bool allowInsecure = false,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client() {
    if (baseUrl.scheme != 'https' && !allowInsecure) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'must be https');
    }
  }

  /// Where the server is.
  final Uri baseUrl;

  /// How long a request may take.
  final Duration timeout;

  final http.Client _client;

  @override
  Future<SyncAck> upload(UploadBatch batch, String accessToken) async =>
      SyncAck.fromJson(
        await _send('POST', ServerApi.sync, accessToken, batch.toJson()),
      );

  @override
  Future<WalletState> wallet(String accessToken) async =>
      WalletState.fromJson(await _send('GET', ServerApi.wallet, accessToken));

  @override
  Future<MergeResult> merge(
    String guestAccessToken,
    String accessToken,
  ) async => MergeResult.fromJson(
    await _send(
      'POST',
      ServerApi.merge,
      accessToken,
      MergeRequest(guestAccessToken: guestAccessToken).toJson(),
    ),
  );

  Future<Map<String, Object?>> _send(
    String method,
    String path,
    String accessToken, [
    Map<String, Object?>? body,
  ]) async {
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers.addAll({
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        HttpHeaders.acceptHeader: 'application/json',
      });
    if (body != null) {
      request
        ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
        ..headers[HttpHeaders.contentEncodingHeader] = 'gzip'
        ..bodyBytes = gzip.encode(utf8.encode(jsonEncode(body)));
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on SocketException catch (error) {
      throw ServerUnavailable(error.message);
    } on http.ClientException catch (error) {
      throw ServerUnavailable(error.message);
    } on TimeoutException {
      throw const ServerUnavailable('timed out');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ServerUnavailable('not JSON (${response.statusCode})');
    }
    if (json is! Map<String, Object?>) {
      throw ServerUnavailable('not a JSON object (${response.statusCode})');
    }
    if (response.statusCode >= 500) {
      throw ServerUnavailable('status ${response.statusCode}');
    }
    if (response.statusCode != 200) {
      throw ServerRefused(
        response.statusCode,
        json['error'] as String? ?? 'unknown',
        json['message'] as String? ?? '',
      );
    }
    return json;
  }
}
