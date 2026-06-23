import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/harvest_sync_engine.dart';
import '../core/logic/recommendation_engine.dart';
import '../core/logic/saturation_engine.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
import '../models/production_report.dart';
import 'auth_controller.dart';
import 'core_providers.dart';

// ── Farmer-scoped reads ──────────────────────────────────────────────────────

/// Farms owned by the signed-in farmer.
final farmsProvider = FutureProvider.autoDispose<List<Farm>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(farmRepositoryProvider).forOwner(profile.id);
});

/// The farmer's primary farm (first one), if any.
final primaryFarmProvider = FutureProvider.autoDispose<Farm?>((ref) async {
  final farms = await ref.watch(farmsProvider.future);
  return farms.isEmpty ? null : farms.first;
});

/// Crop declarations owned by the signed-in farmer.
final declarationsProvider =
    FutureProvider.autoDispose<List<CropDeclaration>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(declarationRepositoryProvider).forFarmer(profile.id);
});

/// All declarations across farmers — the municipal dataset feeding saturation,
/// harvest synchronization, and the cooperative supply dashboard.
final allDeclarationsProvider =
    FutureProvider.autoDispose<List<CropDeclaration>>((ref) async {
  return ref.watch(declarationRepositoryProvider).all();
});

/// Expenses for a specific declaration.
final expensesForDeclarationProvider = FutureProvider.autoDispose
    .family<List<Expense>, String>((ref, declarationId) async {
  return ref
      .watch(expenseRepositoryProvider)
      .forDeclaration(declarationId);
});

/// All expenses logged by the signed-in farmer.
final farmerExpensesProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(expenseRepositoryProvider).forFarmer(profile.id);
});

/// The farmer's agronomic logbook.
final logbookProvider =
    FutureProvider.autoDispose<List<LogbookEntry>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(logbookRepositoryProvider).forFarmer(profile.id);
});

/// The farmer's calamity / incident reports.
final calamityProvider =
    FutureProvider.autoDispose<List<CalamityReport>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(calamityRepositoryProvider).forFarmer(profile.id);
});

/// The farmer's post-harvest production reports.
final productionReportsProvider =
    FutureProvider.autoDispose<List<ProductionReport>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(productionRepositoryProvider).forFarmer(profile.id);
});

/// A production report for a specific declaration (null until harvested).
final productionForDeclarationProvider = FutureProvider.autoDispose
    .family<ProductionReport?, String>((ref, declarationId) async {
  return ref
      .watch(productionRepositoryProvider)
      .forDeclaration(declarationId);
});

// ── Cooperative-scoped reads ─────────────────────────────────────────────────

/// The cooperative the signed-in user belongs to / administers.
final cooperativeProvider =
    FutureProvider.autoDispose<Cooperative?>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final coopId = profile?.cooperativeId;
  if (coopId == null) return null;
  return ref.watch(cooperativeRepositoryProvider).byId(coopId);
});

/// Buy-back programs / alternative market channels for the cooperative.
final marketChannelsProvider =
    FutureProvider.autoDispose<List<MarketChannel>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final coopId = profile?.cooperativeId;
  if (coopId == null) return const [];
  return ref.watch(marketChannelRepositoryProvider).forCooperative(coopId);
});

// ── Derived analytics (Objectives 1 & 3) ─────────────────────────────────────

/// Market Saturation Index for every crop, sorted by risk (descending).
final saturationProvider =
    FutureProvider.autoDispose<List<SaturationResult>>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  return SaturationEngine.forAllCrops(declarations);
});

/// Harvest peaks (crop × ISO week) across the municipality.
final harvestPeaksProvider =
    FutureProvider.autoDispose<List<HarvestPeak>>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  return HarvestSyncEngine.peaks(declarations);
});

/// Staggering suggestions for congested harvest windows.
final harvestSuggestionsProvider =
    FutureProvider.autoDispose<List<SyncSuggestion>>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  return HarvestSyncEngine.suggestions(declarations);
});

/// Ranked single-crop recommendations for the signed-in farmer's context.
final recommendationsProvider =
    FutureProvider.autoDispose<List<CropRecommendation>>((ref) async {
  final farm = await ref.watch(primaryFarmProvider.future);
  final declarations = await ref.watch(allDeclarationsProvider.future);
  return RecommendationEngine.recommend(
    farm: farm,
    allDeclarations: declarations,
    season: Season.forMonth(DateTime.now().month),
  );
});

/// Intercropping (mix-and-match) recommendations derived from the ranked list.
final intercropProvider =
    FutureProvider.autoDispose<List<IntercropRecommendation>>((ref) async {
  final ranked = await ref.watch(recommendationsProvider.future);
  return RecommendationEngine.intercrops(ranked);
});
