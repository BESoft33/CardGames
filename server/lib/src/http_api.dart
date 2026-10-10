import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'sync_service.dart';

/// The largest request body accepted, after decompression.
const int maxBodyBytes = 4 * 1024 * 1024;

/// The server's HTTP API ([ServerApi]) over [service], with players
/// identified by [verifier]. Logs carry no tokens and no personal data
/// (AGENTS.md §12).
Handler buildHandler({
  required SyncService service,
  required TokenVerifier verifier,
}) {
  Future<AuthUser> caller(Request request) async {
    final header = request.headers[HttpHeaders.authorizationHeader] ?? '';
    const prefix = 'Bearer ';
    final user = header.startsWith(prefix)
        ? await verifier.verify(header.substring(prefix.length).trim())
        : null;
    if (user == null) {
      throw const ApiException(
        401,
        ApiErrors.unauthorized,
        'a valid access token is required',
      );
    }
    return user;
  }

  final router = Router()
    ..get(ServerApi.health, (Request request) => Response.ok('ok'))
    ..get(ServerApi.wallet, (Request request) async {
      final user = await caller(request);
      return _json(200, (await service.wallet(user)).toJson());
    })
    ..post(ServerApi.sync, (Request request) async {
      final user = await caller(request);
      final batch = UploadBatch.fromJson(await _body(request));
      return _json(200, (await service.upload(user, batch)).toJson());
    })
    ..post(ServerApi.merge, (Request request) async {
      final user = await caller(request);
      final asked = MergeRequest.fromJson(await _body(request));
      final guest = await verifier.verify(asked.guestAccessToken);
      if (guest == null) {
        throw const ApiException(
          400,
          ApiErrors.badRequest,
          'the guest token is not valid',
        );
      }
      return _json(200, (await service.merge(user, guest)).toJson());
    });

  return const Pipeline().addMiddleware(_errors).addHandler(router.call);
}

/// Turns refusals into JSON answers, and hides other failures' details.
Handler _errors(Handler inner) => (request) async {
  try {
    return await inner(request);
  } on ApiException catch (error) {
    return _json(error.status, {'error': error.code, 'message': error.message});
  } on FormatException catch (error) {
    return _json(400, {
      'error': ApiErrors.badRequest,
      'message': error.message,
    });
  } on Object catch (error, stack) {
    stderr.writeln('${request.method} ${request.url.path}: $error\n$stack');
    return _json(500, {'error': 'internal', 'message': 'internal error'});
  }
};

Response _json(int status, Map<String, Object?> body) => Response(
  status,
  body: jsonEncode(body),
  headers: {HttpHeaders.contentTypeHeader: 'application/json'},
);

/// The request body as a JSON object, gunzipped if it was compressed.
Future<Map<String, Object?>> _body(Request request) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxBodyBytes) {
      throw const ApiException(413, ApiErrors.badRequest, 'body too large');
    }
  }
  final gzipped =
      request.headers[HttpHeaders.contentEncodingHeader]?.toLowerCase() ==
      'gzip';
  final List<int> plain;
  try {
    plain = gzipped ? gzip.decode(bytes) : bytes;
  } on FormatException {
    throw const ApiException(400, ApiErrors.badRequest, 'bad gzip body');
  }
  if (plain.length > maxBodyBytes) {
    throw const ApiException(413, ApiErrors.badRequest, 'body too large');
  }
  final json = jsonDecode(utf8.decode(plain));
  if (json is! Map<String, Object?>) {
    throw const FormatException('the body is not a JSON object');
  }
  return json;
}
