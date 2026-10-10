import 'package:google_sign_in/google_sign_in.dart';

/// What a Google sign-in gives the app: tokens to exchange with Supabase,
/// and a name to show. The email address is not kept (AGENTS.md §12).
typedef GoogleIdentity = ({
  String idToken,
  String? accessToken,
  String? displayName,
});

/// Signs the player in with Google, natively (AGENTS.md §10).
abstract interface class GoogleIdentitySource {
  /// Asks the player to choose a Google account. Returns null if they
  /// cancel. Throws a [GoogleSignInException] if sign-in fails.
  Future<GoogleIdentity?> signIn();

  /// Forgets the Google account chosen, so the next sign-in asks again.
  Future<void> signOut();
}

/// Google sign-in through the `google_sign_in` plugin.
///
/// [webClientId] is the OAuth client of type "Web application" that
/// Supabase checks ID tokens against; [iosClientId] is the iOS client.
/// Both come from Google Cloud (docs/backend-setup.md).
final class PluginGoogleIdentitySource implements GoogleIdentitySource {
  /// Creates the source.
  PluginGoogleIdentitySource({
    required this.webClientId,
    required this.iosClientId,
  });

  /// The Web application client ID.
  final String webClientId;

  /// The iOS client ID, or empty.
  final String iosClientId;

  Future<void>? _ready;

  /// The scopes whose access token Supabase may check against the ID token.
  static const List<String> _scopes = ['email', 'profile'];

  Future<void> _initialize() => _ready ??= GoogleSignIn.instance.initialize(
    clientId: iosClientId.isEmpty ? null : iosClientId,
    serverClientId: webClientId,
  );

  @override
  Future<GoogleIdentity?> signIn() async {
    await _initialize();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google gave no ID token',
      );
    }
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    return (
      idToken: idToken,
      accessToken: authorization.accessToken,
      displayName: account.displayName,
    );
  }

  @override
  Future<void> signOut() async {
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }
}

/// No Google sign-in in this build: every attempt counts as cancelled.
final class NoGoogleIdentity implements GoogleIdentitySource {
  /// Creates the source.
  const NoGoogleIdentity();

  @override
  Future<GoogleIdentity?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}
