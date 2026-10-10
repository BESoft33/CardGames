import 'dart:async';
import 'dart:io';

import 'package:cardgames_server/cardgames_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Runs the game server. Its settings come from the environment, never from
/// the repository (AGENTS.md §12; docs/backend-setup.md):
///
/// - `PORT`: where to listen, 8080 if unset. The host in front of it serves
///   HTTPS (AGENTS.md §12).
/// - `DATABASE_URL`: the Supabase database's `postgresql://` connection
///   string, for the `postgres` role, with `sslmode=require`.
/// - `SUPABASE_URL`: the project's URL, such as
///   `https://ylvwsollcphtjvzvtpjq.supabase.co`.
/// - `SUPABASE_PUBLISHABLE_KEY`: the project's publishable (anon) key.
Future<void> main() async {
  String setting(String name) {
    final value = Platform.environment[name];
    if (value == null || value.isEmpty) {
      stderr.writeln('The environment variable $name is not set.');
      exit(64);
    }
    return value;
  }

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final store = PostgresStore.fromUrl(setting('DATABASE_URL'));
  final verifier = SupabaseTokenVerifier(
    supabaseUrl: Uri.parse(setting('SUPABASE_URL')),
    apiKey: setting('SUPABASE_PUBLISHABLE_KEY'),
  );
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(
        buildHandler(
          service: SyncService(store: store),
          verifier: verifier,
        ),
      );
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('card.games server listening on port ${server.port}');

  if (!Platform.isWindows) {
    unawaited(
      ProcessSignal.sigterm.watch().first.then((_) async {
        await server.close();
        await store.close();
        exit(0);
      }),
    );
  }
}
