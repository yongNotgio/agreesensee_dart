import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cache/local_cache.dart';
import 'core/config/app_config.dart';
import 'data/dataset_loader.dart';
import 'providers/core_providers.dart';
import 'repositories/demo_seed.dart';

/// Application entry point.
///
/// Boots the offline cache, initializes Supabase when credentials are present,
/// and seeds demo data when they are not — then runs the app with the resolved
/// singletons injected into the Riverpod graph.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Supabase credentials from the bundled `.env` (optional — the app still
  // boots in demo mode if it's absent or empty).
  var envUrl = '';
  var envKey = '';
  try {
    await dotenv.load(fileName: '.env');
    envUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
    envKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
  } on Object {
    // No .env bundled; fall back to --dart-define / demo mode.
  }
  AppConfig.hydrateFromEnv(url: envUrl, anonKey: envKey);

  final prefs = await SharedPreferences.getInstance();

  // Load and calibrate the market datasets (Objectives 1 & 2). Falls back to
  // bundled catalog baselines if the assets cannot be read.
  final marketDataset = await DatasetLoader.load();

  var supabaseReady = false;
  if (!AppConfig.isDemoMode) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // The publishable (anon) key. The env var keeps its conventional name.
        anonKey: AppConfig.supabaseAnonKey, // ignore: deprecated_member_use
      );
      supabaseReady = true;
    } on Object {
      // Initialization failed (e.g. transient network / bad credentials) —
      // degrade gracefully to offline demo mode rather than crash on boot.
      supabaseReady = false;
    }
  }

  if (!supabaseReady) {
    // No backend configured or init failed → seed the on-device store so every
    // portal is fully navigable offline for evaluation / thesis defense.
    AppConfig.hydrateFromEnv(url: '', anonKey: ''); // force demo mode
    await DemoSeed.ensureSeeded(LocalCache(prefs));
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        marketDatasetProvider.overrideWithValue(marketDataset),
      ],
      child: const AgriSenseApp(),
    ),
  );
}
