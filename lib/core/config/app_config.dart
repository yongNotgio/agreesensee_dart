/// Global, compile-time application configuration.
///
/// Supabase credentials are injected at build time using `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// When the credentials are absent the app boots in **demo mode**: every
/// repository is backed by the on-device offline cache (seeded with realistic
/// sample data) instead of the network. This keeps the application fully
/// runnable for thesis defense / evaluation without provisioning a backend,
/// while the exact same repository surface targets Supabase in production.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// True when no live Supabase project is wired in. Repositories fall back to
  /// the seeded offline store so the UI and business logic remain demoable.
  static bool get isDemoMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static const String appName = 'AgriSense';
  static const String appTagline =
      'Integrated Agricultural Decision Support System';

  /// Municipality the pilot targets (per the manuscript: Tubungan, Iloilo).
  static const String municipality = 'Tubungan, Iloilo';
}
