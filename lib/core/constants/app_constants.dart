import '../../models/enums.dart';

/// Static reference data for the pilot municipality. In production this is
/// sourced from the `crops`, `barangays`, and `market_prices` Supabase tables;
/// it is bundled here so the recommendation, saturation, and financial engines
/// have sensible defaults and so demo mode is meaningful offline.
class AppConstants {
  const AppConstants._();

  /// Barangays of Tubungan, Iloilo referenced by the manuscript example
  /// (e.g. "Barangay Igpaho").
  static const List<String> barangays = <String>[
    'Igpaho',
    'Bading',
    'Bagunanay',
    'Bondoc',
    'Buenavista',
    'Cabunga',
    'Igcabugao',
    'Igtuble',
    'Molina',
    'Morubuan',
    'Poblacion',
    'Tabat',
    'Talenton',
    'Teniente Loling',
  ];

  /// Default planting-window risk threshold: number of farmers harvesting the
  /// same crop in the same ISO week before the period is flagged as congested
  /// (Phase 9 — harvest synchronization).
  static const int harvestCongestionThreshold = 5;
}

/// A single reference crop with the agronomic and economic baselines used by
/// the local engines. Mirrors a row of the Supabase `crops` table.
class CropProfile {
  const CropProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.suitableSeasons,
    required this.growthDurationDays,
    required this.baselineYieldPerHa,
    required this.unit,
    required this.baselinePricePerKg,
    required this.projectedDemandTons,
    required this.companions,
    required this.landSuitabilityScore,
  });

  final String id;
  final String name;
  final String category;

  /// Seasons in which the crop performs well — drives seasonal suitability.
  final List<Season> suitableSeasons;

  /// Days from planting to harvest — used to derive expected harvest dates.
  final int growthDurationDays;

  /// Typical yield in kilograms per hectare under average conditions.
  final double baselineYieldPerHa;
  final String unit;

  /// Average farmgate price per kilogram (PHP).
  final double baselinePricePerKg;

  /// Projected municipal market demand in metric tons for the season — the
  /// denominator of the Market Saturation Index.
  final double projectedDemandTons;

  /// Crop ids that intercrop well with this crop (mix-and-match strategy).
  final List<String> companions;

  /// 0–1 score for how suitable the local soil/terrain is for the crop.
  final double landSuitabilityScore;

  bool suitsSeason(Season season) => suitableSeasons.contains(season);
}

/// Bundled catalog of high-value crops commonly grown in the pilot area.
class CropCatalog {
  const CropCatalog._();

  static const List<CropProfile> crops = <CropProfile>[
    CropProfile(
      id: 'ampalaya',
      name: 'Ampalaya',
      category: 'Vegetable',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 70,
      baselineYieldPerHa: 12000,
      unit: 'kg',
      baselinePricePerKg: 45,
      projectedDemandTons: 500,
      companions: ['corn', 'string_beans'],
      landSuitabilityScore: 0.82,
    ),
    CropProfile(
      id: 'eggplant',
      name: 'Eggplant',
      category: 'Vegetable',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 80,
      baselineYieldPerHa: 18000,
      unit: 'kg',
      baselinePricePerKg: 40,
      projectedDemandTons: 620,
      companions: ['string_beans', 'okra'],
      landSuitabilityScore: 0.88,
    ),
    CropProfile(
      id: 'okra',
      name: 'Okra',
      category: 'Vegetable',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 55,
      baselineYieldPerHa: 9000,
      unit: 'kg',
      baselinePricePerKg: 35,
      projectedDemandTons: 410,
      companions: ['eggplant', 'ampalaya'],
      landSuitabilityScore: 0.84,
    ),
    CropProfile(
      id: 'string_beans',
      name: 'String Beans',
      category: 'Legume',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 60,
      baselineYieldPerHa: 8000,
      unit: 'kg',
      baselinePricePerKg: 50,
      projectedDemandTons: 360,
      companions: ['ampalaya', 'eggplant', 'corn'],
      landSuitabilityScore: 0.86,
    ),
    CropProfile(
      id: 'tomato',
      name: 'Tomato',
      category: 'Vegetable',
      suitableSeasons: [Season.dry],
      growthDurationDays: 75,
      baselineYieldPerHa: 20000,
      unit: 'kg',
      baselinePricePerKg: 38,
      projectedDemandTons: 540,
      companions: ['okra', 'string_beans'],
      landSuitabilityScore: 0.79,
    ),
    CropProfile(
      id: 'corn',
      name: 'Sweet Corn',
      category: 'Cereal',
      suitableSeasons: [Season.wet],
      growthDurationDays: 90,
      baselineYieldPerHa: 6000,
      unit: 'kg',
      baselinePricePerKg: 22,
      projectedDemandTons: 700,
      companions: ['string_beans', 'ampalaya'],
      landSuitabilityScore: 0.81,
    ),
    CropProfile(
      id: 'squash',
      name: 'Squash',
      category: 'Vegetable',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 85,
      baselineYieldPerHa: 15000,
      unit: 'kg',
      baselinePricePerKg: 25,
      projectedDemandTons: 480,
      companions: ['corn', 'okra'],
      landSuitabilityScore: 0.83,
    ),
    CropProfile(
      id: 'pechay',
      name: 'Pechay',
      category: 'Leafy Vegetable',
      suitableSeasons: [Season.dry, Season.wet],
      growthDurationDays: 35,
      baselineYieldPerHa: 11000,
      unit: 'kg',
      baselinePricePerKg: 30,
      projectedDemandTons: 300,
      companions: ['okra', 'eggplant'],
      landSuitabilityScore: 0.80,
    ),
  ];

  static CropProfile? byId(String id) {
    for (final c in crops) {
      if (c.id == id) return c;
    }
    return null;
  }

  static CropProfile byIdOrFirst(String id) => byId(id) ?? crops.first;

  static String nameFor(String id) => byId(id)?.name ?? id;
}
