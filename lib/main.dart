import 'package:flutter/material.dart';
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

  final prefs = await SharedPreferences.getInstance();

  // Load and calibrate the market datasets (Objectives 1 & 2). Falls back to
  // bundled catalog baselines if the assets cannot be read.
  final marketDataset = await DatasetLoader.load();

  if (AppConfig.isDemoMode) {
    // No backend configured → seed the on-device store so every portal is
    // fully navigable offline for evaluation / thesis defense.
    await DemoSeed.ensureSeeded(LocalCache(prefs));
  } else {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // The publishable (anon) key. The env var keeps its conventional name.
      anonKey: AppConfig.supabaseAnonKey, // ignore: deprecated_member_use
    );
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
