import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the online services are. Read from the env file passed with
/// `--dart-define-from-file=env/dev.json`, which stays out of the
/// repository (AGENTS.md §12; docs/backend-setup.md). None of these values
/// is a secret: the app's users can see them all.
final class BackendConfig {
  /// Creates a configuration.
  const BackendConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.serverUrl,
    required this.googleWebClientId,
    required this.googleIosClientId,
  });

  /// No online services: offline play only, as in tests.
  static const BackendConfig offline = BackendConfig(
    supabaseUrl: '',
    supabaseKey: '',
    serverUrl: '',
    googleWebClientId: '',
    googleIosClientId: '',
  );

  /// The configuration this build was given.
  static const BackendConfig fromEnvironment = BackendConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    serverUrl: String.fromEnvironment('SERVER_URL'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  );

  /// The Supabase project, such as `https://ylvwsollcphtjvzvtpjq.supabase.co`.
  final String supabaseUrl;

  /// The project's publishable (anon) key.
  final String supabaseKey;

  /// The game server, such as `https://cardgames-server.example.com`.
  final String serverUrl;

  /// The Google OAuth client ID of type "Web application", which Supabase
  /// checks ID tokens against.
  final String googleWebClientId;

  /// The Google OAuth client ID for iOS.
  final String googleIosClientId;

  static bool _https(String url) => Uri.tryParse(url)?.scheme == 'https';

  /// Whether Supabase is set, over HTTPS (AGENTS.md §12): guests get
  /// accounts and players can sign in. Offline play needs none of it.
  bool get hasSupabase => _https(supabaseUrl) && supabaseKey.isNotEmpty;

  /// Whether the game server is set, over HTTPS: progress is uploaded and
  /// coins are confirmed.
  bool get hasServer => _https(serverUrl);

  /// Whether sync works in this build: Supabase and the game server are
  /// both set.
  bool get isOnline => hasSupabase && hasServer;

  /// Whether Google sign-in works in this build. It needs Supabase, not the
  /// game server (docs/decisions.md D-030).
  bool get canSignInWithGoogle => hasSupabase && googleWebClientId.isNotEmpty;
}

/// The online services of this build.
final backendConfigProvider = Provider<BackendConfig>(
  (ref) => BackendConfig.fromEnvironment,
);
