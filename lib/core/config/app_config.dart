/// Global application configuration.
///
/// Supabase credentials are resolved at startup from two sources, in priority
/// order:
///   1. `--dart-define` (best for CI / release builds), then
///   2. a bundled `.env` file (loaded in `main()` via `flutter_dotenv`):
///
/// ```
/// # .env
/// SUPABASE_URL=https://xxxx.supabase.co
/// SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// When neither supplies credentials the app boots in **demo mode**: every
/// repository is backed by the on-device offline cache (seeded with realistic
/// sample data) instead of the network. This keeps the application fully
/// runnable without a backend, while the exact same repository surface targets
/// Supabase in production.
class AppConfig {
  const AppConfig._();

  // Compile-time overrides (highest priority).
  static const String _defineUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _defineKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // Runtime values populated from `.env` during bootstrap.
  static String _envUrl = '';
  static String _envKey = '';

  /// Called once from `main()` after the `.env` file is loaded.
  static void hydrateFromEnv({required String url, required String anonKey}) {
    _envUrl = url.trim();
    _envKey = anonKey.trim();
  }

  static String get supabaseUrl =>
      _defineUrl.isNotEmpty ? _defineUrl : _envUrl;

  static String get supabaseAnonKey =>
      _defineKey.isNotEmpty ? _defineKey : _envKey;

  /// True when no live Supabase project is wired in. Repositories fall back to
  /// the seeded offline store so the UI and business logic remain demoable.
  static bool get isDemoMode =>
      supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static const String appName = 'AgriSense';
  static const String appTagline =
      'Integrated Agricultural Decision Support System';

  /// Municipality the pilot targets (per the manuscript: Tubungan, Iloilo).
  static const String municipality = 'Tubungan, Iloilo';
}
