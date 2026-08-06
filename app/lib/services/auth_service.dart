import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

/// Why the player is signed in, or why they are not.
enum AuthState {
  /// No backend configured for this build. The game runs fully offline.
  disabled,

  /// Backend is reachable, nobody signed in yet.
  signedOut,

  signingIn,
  signedIn,
  error,
}

/// Google sign-in bridged into Supabase, so paid Gold survives a reinstall.
///
/// Signing in is entirely optional: every code path here degrades to
/// [AuthState.disabled] or [AuthState.signedOut] and the single-player game
/// keeps working from local storage alone.
class AuthService extends ChangeNotifier {
  AuthService({this.client, GoogleSignIn? google})
      : _google = google ?? GoogleSignIn.instance;

  /// Injected by tests; production falls back to the shared Supabase instance.
  final SupabaseClient? client;
  final GoogleSignIn _google;

  AuthState state =
      BackendConfig.hasGoogleSignIn ? AuthState.signedOut : AuthState.disabled;
  String? message;

  /// Set by the owner from the saved profile: true once the player has
  /// explicitly linked a Google account on this device. The silent re-auth
  /// at startup keys off it — without the gate, launching the game could
  /// surface a Google account prompt in the middle of the opening
  /// cinematic for a player who never asked to sign in.
  bool accountLinked = false;

  bool _googleReady = false;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  User? get user => BackendConfig.hasBackend ? _supabase.auth.currentUser : null;

  bool get isSignedIn => user != null;

  /// A display name for the account chip, falling back to the email.
  String? get displayName {
    final metadata = user?.userMetadata;
    final name = metadata?['full_name'] ?? metadata?['name'];
    return (name as String?) ?? user?.email;
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await _google.initialize(
      serverClientId: BackendConfig.googleServerClientId,
    );
    _googleReady = true;
  }

  /// Re-establishes a previous session without showing any UI.
  ///
  /// Supabase restores its own session from disk, so this only needs to cover
  /// the case where that session is gone but Google still knows the player.
  /// That Google attempt is only made for a player who linked their account
  /// before; anyone else stays signed out and, crucially, unprompted.
  Future<void> restoreSession() async {
    if (state == AuthState.disabled) return;

    if (_supabase.auth.currentSession != null) {
      state = AuthState.signedIn;
      notifyListeners();
      return;
    }

    if (!accountLinked) return;

    try {
      await _ensureGoogleReady();
      final account = await _google.attemptLightweightAuthentication();
      if (account == null) return;
      await _exchange(account);
    } catch (error) {
      // A silent attempt must never surface an error to the player.
      debugPrint('Silent sign-in skipped: $error');
    }
  }

  /// Shows the Google account picker. Returns true once Supabase has a session.
  Future<bool> signIn() async {
    if (state == AuthState.disabled) {
      message = 'This build has no backend configured.';
      notifyListeners();
      return false;
    }

    state = AuthState.signingIn;
    message = null;
    notifyListeners();

    try {
      await _ensureGoogleReady();
      if (!_google.supportsAuthenticate()) {
        _fail('Google sign-in is not supported on this device.');
        return false;
      }
      await _exchange(await _google.authenticate());
      return state == AuthState.signedIn;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        state = AuthState.signedOut;
        message = null;
        notifyListeners();
        return false;
      }
      _fail('Google sign-in failed: ${error.code.name}');
      return false;
    } catch (error) {
      _fail('Could not sign in: $error');
      return false;
    }
  }

  Future<void> _exchange(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _fail('Google did not return an ID token.');
      return;
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    state = AuthState.signedIn;
    message = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (state == AuthState.disabled) return;
    try {
      await _google.signOut();
    } catch (error) {
      debugPrint('Google sign-out failed: $error');
    }
    await _supabase.auth.signOut();
    state = AuthState.signedOut;
    message = null;
    notifyListeners();
  }

  void _fail(String text) {
    state = AuthState.error;
    message = text;
    notifyListeners();
  }
}
