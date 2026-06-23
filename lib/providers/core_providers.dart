import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/local_cache.dart';
import '../core/config/app_config.dart';
import '../core/network/connectivity_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/entity_repositories.dart';

/// Holds singletons resolved during app bootstrap (see `main.dart`), injected
/// into the provider graph via [ProviderScope] overrides.
class Bootstrap {
  const Bootstrap({required this.prefs});
  final SharedPreferences prefs;
}

/// Overridden in `main()` with the real [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The persistent offline cache.
final localCacheProvider = Provider<LocalCache>(
  (ref) => LocalCache(ref.watch(sharedPreferencesProvider)),
);

/// The live Supabase client, or `null` in demo mode.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (AppConfig.isDemoMode) return null;
  return Supabase.instance.client;
});

/// True when the app is running without a configured Supabase backend.
final isDemoModeProvider = Provider<bool>((ref) => AppConfig.isDemoMode);

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

/// Online/offline signal. Defaults to `true` (and always true in demo mode,
/// since the local store is always available).
final connectivityProvider = StreamProvider<bool>((ref) {
  if (AppConfig.isDemoMode) return Stream.value(true);
  return ref.watch(connectivityServiceProvider).onStatusChange;
});

// ── Repositories ───────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final farmRepositoryProvider = Provider<FarmRepository>(
  (ref) => FarmRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final declarationRepositoryProvider = Provider<DeclarationRepository>(
  (ref) => DeclarationRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final productionRepositoryProvider = Provider<ProductionRepository>(
  (ref) => ProductionRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final logbookRepositoryProvider = Provider<LogbookRepository>(
  (ref) => LogbookRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final calamityRepositoryProvider = Provider<CalamityRepository>(
  (ref) => CalamityRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final cooperativeRepositoryProvider = Provider<CooperativeRepository>(
  (ref) => CooperativeRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

final marketChannelRepositoryProvider = Provider<MarketChannelRepository>(
  (ref) => MarketChannelRepository(
    client: ref.watch(supabaseClientProvider),
    cache: ref.watch(localCacheProvider),
  ),
);
