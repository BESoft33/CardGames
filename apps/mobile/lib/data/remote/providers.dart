import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/backend_config.dart';
import 'auth_repository.dart';
import 'game_server.dart';
import 'google_identity.dart';
import 'session_store.dart';

/// Where Supabase sessions are kept: secure storage only (AGENTS.md §12).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(),
);

/// Accounts on Supabase Auth, or null in a build without Supabase.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final config = ref.watch(backendConfigProvider);
  if (!config.hasSupabase) return null;
  return SupabaseAuthRepository(
    supabaseUrl: config.supabaseUrl,
    supabaseKey: config.supabaseKey,
    sessions: ref.watch(sessionStoreProvider),
    google: config.canSignInWithGoogle
        ? PluginGoogleIdentitySource(
            webClientId: config.googleWebClientId,
            iosClientId: config.googleIosClientId,
          )
        : const NoGoogleIdentity(),
  );
});

/// The game server, or null in a build without one.
final gameServerProvider = Provider<GameServer?>((ref) {
  final config = ref.watch(backendConfigProvider);
  return config.hasServer ? HttpGameServer(Uri.parse(config.serverUrl)) : null;
});
