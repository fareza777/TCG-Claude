/// Supabase connection details for the Shardfall backend.
///
/// The URL and publishable key are meant to ship inside the app — the security
/// boundary is Row Level Security on the server, not secrecy of these values.
/// They stay overridable with `--dart-define` so a staging build can point
/// somewhere else without a code change.
///
/// [googleServerClientId] has no default on purpose: it is created per Play
/// Console app and there is nothing sensible to fall back to. Without it the
/// app runs exactly as before, fully offline.
abstract final class BackendConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vqssjwewtjgekuyzzggo.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_bXLnHl5yq0ylgclYB4l6ww_yFQU7Te8',
  );

  /// The Google Cloud OAuth **Web** client ID, not the Android one.
  ///
  /// Google mints the ID token with this as its audience, which is the value
  /// Supabase checks. Passing the Android client ID here makes sign-in fail
  /// with an audience mismatch.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Allows a staged build to ship the PvP client before the non-production
  /// service is ready. It is deliberately compile-time only: no secret is
  /// used as a feature flag.
  static const pvpEnabled =
      bool.fromEnvironment('PVP_ENABLED', defaultValue: true);

  static bool get hasBackend => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool get pvpAvailable => hasBackend && pvpEnabled;

  static bool get hasGoogleSignIn =>
      hasBackend && googleServerClientId.isNotEmpty;
}
