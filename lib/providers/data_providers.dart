import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/logic/crop_calendar_engine.dart';
import '../core/logic/harvest_sync_engine.dart';
import '../core/logic/recommendation_engine.dart';
import '../core/logic/saturation_engine.dart';
import '../core/logic/suitability_engine.dart';
import '../models/barangay_assignment.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/demand_signal.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
import '../models/planned_activity.dart';
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

/// Hectares already committed to active declarations on a given farm.
///
/// The declaration form validates against this: a farmer with 1.5 ha cannot
/// declare 50 ha, which the app previously allowed without complaint.
final committedAreaProvider =
    FutureProvider.autoDispose.family<double, String>((ref, farmId) async {
  final declarations = await ref.watch(declarationsProvider.future);
  return declarations
      .where((d) => d.farmId == farmId && d.status.isActive)
      .fold<double>(0, (sum, d) => sum + d.areaHa);
});

/// Expenses for a specific declaration.
final expensesForDeclarationProvider = FutureProvider.autoDispose
    .family<List<Expense>, String>((ref, declarationId) async {
  return ref.watch(expenseRepositoryProvider).forDeclaration(declarationId);
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
  return ref.watch(productionRepositoryProvider).forDeclaration(declarationId);
});

// ── Crop calendar (scheduled agronomic operations) ───────────────────────────

/// Every scheduled operation for the signed-in farmer, across declarations.
final plannedActivitiesProvider =
    FutureProvider.autoDispose<List<PlannedActivity>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return const [];
  return ref.watch(plannedActivityRepositoryProvider).forFarmer(profile.id);
});

/// Scheduled operations for one declaration.
final plannedForDeclarationProvider = FutureProvider.autoDispose
    .family<List<PlannedActivity>, String>((ref, declarationId) async {
  return ref
      .watch(plannedActivityRepositoryProvider)
      .forDeclaration(declarationId);
});

/// Operations due today or already overdue — the farmer's "do this now" list.
final dueActivitiesProvider =
    FutureProvider.autoDispose<List<PlannedActivity>>((ref) async {
  final all = await ref.watch(plannedActivitiesProvider.future);
  return CropCalendarEngine.dueBy(all, DateTime.now());
});

/// Operations scheduled in the next [7] days, excluding those already due.
final upcomingActivitiesProvider =
    FutureProvider.autoDispose<List<PlannedActivity>>((ref) async {
  final all = await ref.watch(plannedActivitiesProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: 7));
  return all
      .where((a) =>
          a.isPending &&
          a.scheduledOn.isAfter(today) &&
          !a.scheduledOn.isAfter(horizon))
      .toList()
    ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));
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

/// Demand this cooperative has declared.
final myDemandSignalsProvider =
    FutureProvider.autoDispose<List<DemandSignal>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final coopId = profile?.cooperativeId;
  if (coopId == null) return const [];
  return ref.watch(demandSignalRepositoryProvider).forCooperative(coopId);
});

/// Demand declared by every cooperative — the municipal demand picture that
/// feeds the saturation denominator.
final allDemandSignalsProvider =
    FutureProvider.autoDispose<List<DemandSignal>>((ref) async {
  return ref.watch(demandSignalRepositoryProvider).all();
});

/// The technician or BAW assigned to a barangay, surfaced on the farmer's
/// dashboard as an advisory contact.
final assignedTechnicianProvider = FutureProvider.autoDispose
    .family<BarangayAssignment?, String>((ref, barangay) async {
  final list =
      await ref.watch(barangayAssignmentRepositoryProvider).forBarangay(barangay);
  if (list.isEmpty) return null;
  // Prefer a technician over a barangay agricultural worker when both exist.
  return list.firstWhere(
    (a) => a.role == UserRole.technician,
    orElse: () => list.first,
  );
});

/// The technician assigned to the signed-in farmer's barangay.
final myTechnicianProvider =
    FutureProvider.autoDispose<BarangayAssignment?>((ref) async {
  final barangay = ref.watch(currentProfileProvider)?.barangay;
  if (barangay == null) return null;
  return ref.watch(assignedTechnicianProvider(barangay).future);
});

// ── Demand resolution ────────────────────────────────────────────────────────

/// Crop id → the demand figure the Saturation Index divides by, resolved in
/// precedence order:
///   1. demand cooperatives have actually declared for the current period
///   2. the municipal monthly baseline for the current month
///   3. the bundled catalog constant
///
/// Carrying the source through means the UI can say *whose* demand this is,
/// rather than presenting an unattributable number.
final demandFiguresProvider =
    FutureProvider.autoDispose<Map<String, DemandFigure>>((ref) async {
  final calibration = ref.watch(calibrationProvider);
  final signals = await ref.watch(allDemandSignalsProvider.future);
  final now = DateTime.now();

  final active = signals.where((s) => s.coversDate(now)).toList();
  final declared = <String, double>{};
  final contributors = <String, Set<String>>{};
  for (final s in active) {
    declared[s.cropId] = (declared[s.cropId] ?? 0) + s.monthlyEquivalentTons;
    contributors.putIfAbsent(s.cropId, () => {}).add(s.cooperativeId);
  }

  final figures = <String, DemandFigure>{};
  final cropIds = <String>{
    ...CropCatalog.crops.map((c) => c.id),
    ...calibration.keys,
    ...declared.keys,
  };

  for (final cropId in cropIds) {
    if (declared.containsKey(cropId) && declared[cropId]! > 0) {
      figures[cropId] = DemandFigure(
        tons: declared[cropId]!,
        source: DemandSource.cooperative,
        contributorCount: contributors[cropId]?.length ?? 0,
      );
      continue;
    }
    final cal = calibration[cropId];
    if (cal != null) {
      figures[cropId] = DemandFigure(
        tons: cal.demandForMonth(now.month),
        source: DemandSource.baseline,
      );
      continue;
    }
    figures[cropId] = DemandFigure(
      tons: CropCatalog.byIdOrFirst(cropId).projectedDemandTons / 12,
      source: DemandSource.catalog,
    );
  }
  return figures;
});

// ── Derived analytics ────────────────────────────────────────────────────────

/// Market Saturation Index for every crop, sorted by risk (descending).
final saturationProvider =
    FutureProvider.autoDispose<List<SaturationResult>>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  final demand = await ref.watch(demandFiguresProvider.future);
  return SaturationEngine.forAllCrops(declarations, demandOverrides: demand);
});

/// Crop × month saturation grid over the next 12 months — the heat map.
final saturationMatrixProvider =
    FutureProvider.autoDispose<SaturationMatrix>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  final calibration = ref.watch(calibrationProvider);
  return SaturationEngine.monthlyMatrix(
    declarations: declarations,
    monthlyDemand: (cropId, month) =>
        calibration[cropId]?.demandForMonth(month) ??
        CropCatalog.byIdOrFirst(cropId).projectedDemandTons / 12,
  );
});

/// Expected supply per barangay per crop — where planting is concentrated.
final supplyByBarangayProvider =
    FutureProvider.autoDispose<Map<String, Map<String, double>>>((ref) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  return SaturationEngine.supplyByBarangay(declarations);
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

/// Ranked single-crop recommendations for the signed-in farmer's barangay.
final recommendationsProvider =
    FutureProvider.autoDispose<List<CropRecommendation>>((ref) async {
  final farm = await ref.watch(primaryFarmProvider.future);
  final declarations = await ref.watch(allDeclarationsProvider.future);
  final demand = await ref.watch(demandFiguresProvider.future);
  final profile = ref.watch(currentProfileProvider);
  return RecommendationEngine.recommend(
    farm: farm,
    allDeclarations: declarations,
    season: Season.forMonth(DateTime.now().month),
    barangay: farm?.barangay ?? profile?.barangay,
    demandOverrides: demand,
    calibration: ref.watch(calibrationProvider),
    agronomy: ref.watch(agronomyDatasetProvider),
  );
});

/// Recommendations for an arbitrary barangay — used by the suitability screen
/// and the post-signup advisory, neither of which requires a farm record.
final recommendationsForBarangayProvider = FutureProvider.autoDispose
    .family<List<CropRecommendation>, String>((ref, barangay) async {
  final declarations = await ref.watch(allDeclarationsProvider.future);
  final demand = await ref.watch(demandFiguresProvider.future);
  return RecommendationEngine.recommend(
    farm: null,
    allDeclarations: declarations,
    season: Season.forMonth(DateTime.now().month),
    barangay: barangay,
    demandOverrides: demand,
    calibration: ref.watch(calibrationProvider),
    agronomy: ref.watch(agronomyDatasetProvider),
  );
});

/// Intercropping (mix-and-match) recommendations derived from the ranked list.
final intercropProvider =
    FutureProvider.autoDispose<List<IntercropRecommendation>>((ref) async {
  final ranked = await ref.watch(recommendationsProvider.future);
  return RecommendationEngine.intercrops(ranked);
});

// ── Land suitability ─────────────────────────────────────────────────────────

/// Every crop ranked by how well it grows in a barangay.
final suitabilityForBarangayProvider = Provider.autoDispose
    .family<List<SuitabilityResult>, String>((ref, barangay) {
  return SuitabilityEngine.rankCropsForBarangay(
    barangay: barangay,
    agronomy: ref.watch(agronomyDatasetProvider),
  );
});

/// The crop × barangay suitability grid, with the farmer's barangay pinned to
/// the top when known.
final suitabilityMatrixProvider =
    Provider.autoDispose<SuitabilityMatrix>((ref) {
  final barangay = ref.watch(currentProfileProvider)?.barangay;
  return SuitabilityEngine.matrix(
    agronomy: ref.watch(agronomyDatasetProvider),
    focusBarangay: barangay,
  );
});
