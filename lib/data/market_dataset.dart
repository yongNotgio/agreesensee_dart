import 'dart:math' as math;

import '../core/constants/app_constants.dart';
import '../core/utils/parsing.dart';
import '../models/enums.dart';

/// Per-crop parameters *derived from the calibration datasets* and consumed by
/// the decision engines. This is the bridge between the raw data
/// (`assets/data/*.json`) and the rule-based models for Objectives 1 & 2.
///
/// Nothing here is a hand-tuned constant: baseline price is the mean of the most
/// recent 12 months of the price history; the scenario bands come from the
/// 10th/90th price percentiles and the observed yield range; the default
/// expense estimate and break-even use the surveyed cost-of-production; and the
/// saturation denominator uses the demand baseline.
class CropCalibration {
  const CropCalibration({
    required this.cropId,
    required this.name,
    required this.category,
    required this.seasons,
    required this.growthDurationDays,
    required this.baselinePricePerKg,
    required this.priceP10,
    required this.priceP50,
    required this.priceP90,
    required this.priceCoefficientOfVariation,
    required this.bestPriceUplift,
    required this.worstPriceDrop,
    required this.meanYieldKgPerHa,
    required this.minYieldKgPerHa,
    required this.maxYieldKgPerHa,
    required this.bestYieldUplift,
    required this.worstYieldDrop,
    required this.costByCategory,
    required this.totalCostPerHa,
    required this.annualDemandTons,
    required this.soilSuitability,
    required this.recentPrices,
  });

  final String cropId;
  final String name;
  final String category;
  final List<Season> seasons;
  final int growthDurationDays;

  /// Mean farmgate price over the most recent 12 months (PHP/kg).
  final double baselinePricePerKg;
  final double priceP10;
  final double priceP50;
  final double priceP90;

  /// Standard deviation ÷ mean over the full price history — a volatility index.
  final double priceCoefficientOfVariation;

  /// Scenario price factors derived from the price distribution.
  final double bestPriceUplift; // (p90 − mean) / mean
  final double worstPriceDrop; // (mean − p10) / mean

  final double meanYieldKgPerHa;
  final double minYieldKgPerHa;
  final double maxYieldKgPerHa;
  final double bestYieldUplift;
  final double worstYieldDrop;

  /// Surveyed cost of production per hectare (PHP), by category.
  final Map<String, double> costByCategory;
  final double totalCostPerHa;

  /// Municipal annual market demand (tons) — saturation denominator.
  final double annualDemandTons;

  /// Land suitability (0..1) by soil type.
  final Map<String, double> soilSuitability;

  /// The trailing 12 months of price points (for sparklines / context).
  final List<double> recentPrices;

  bool suitsSeason(Season s) => seasons.contains(s);

  /// Generic suitability when the farmer's soil is unknown (mean across soils).
  double get landSuitability => soilSuitability.values.isEmpty
      ? 0.8
      : soilSuitability.values.reduce((a, b) => a + b) /
          soilSuitability.values.length;

  /// Suitability for a specific soil type, falling back to the generic mean.
  double suitabilityForSoil(String? soilType) {
    if (soilType == null) return landSuitability;
    final key = soilType.toLowerCase().replaceAll(' ', '_');
    return soilSuitability[key] ?? landSuitability;
  }

  /// Projected net income per hectare at baseline price & mean yield.
  double get projectedNetPerHa =>
      meanYieldKgPerHa * baselinePricePerKg - totalCostPerHa;

  double get projectedDemandTons => annualDemandTons;
}

/// The fully-parsed and calibrated market dataset, keyed by crop id.
class MarketDataset {
  const MarketDataset(this.calibrations);

  final Map<String, CropCalibration> calibrations;

  CropCalibration? forCrop(String cropId) => calibrations[cropId];

  /// Map of crop id → demand (tons) for `SaturationEngine` overrides.
  Map<String, double> get demandOverrides =>
      {for (final c in calibrations.values) c.cropId: c.annualDemandTons};

  bool get isEmpty => calibrations.isEmpty;

  /// Build the calibrated dataset from the decoded JSON asset payloads.
  factory MarketDataset.fromJson({
    required List<dynamic> agronomics,
    required List<dynamic> costs,
    required List<dynamic> prices,
    required List<dynamic> demand,
  }) {
    // Index raw rows by crop id.
    final agroById = {
      for (final r in agronomics.cast<Map<String, dynamic>>())
        asString(r['crop_id']): r
    };
    final costById = {
      for (final r in costs.cast<Map<String, dynamic>>())
        asString(r['crop_id']): r
    };
    final demandById = {
      for (final r in demand.cast<Map<String, dynamic>>())
        asString(r['crop_id']): r
    };

    // Group price rows by crop, ordered by (year, month).
    final pricesById = <String, List<Map<String, dynamic>>>{};
    for (final r in prices.cast<Map<String, dynamic>>()) {
      pricesById.putIfAbsent(asString(r['crop_id']), () => []).add(r);
    }
    for (final list in pricesById.values) {
      list.sort((a, b) {
        final ay = asInt(a['year']), by = asInt(b['year']);
        if (ay != by) return ay.compareTo(by);
        return asInt(a['month']).compareTo(asInt(b['month']));
      });
    }

    final calibrations = <String, CropCalibration>{};
    for (final cropId in agroById.keys) {
      final agro = agroById[cropId]!;
      final priceRows = pricesById[cropId] ?? const [];
      final series = priceRows.map((r) => asDouble(r['price_per_kg'])).toList();
      if (series.isEmpty) continue;

      final recent =
          series.length <= 12 ? series : series.sublist(series.length - 12);
      final baseline = _mean(recent);
      final p10 = _percentile(series, 10);
      final p50 = _percentile(series, 50);
      final p90 = _percentile(series, 90);
      final cov = baseline == 0 ? 0.0 : _stdDev(series) / _mean(series);

      final yMean = asDouble(agro['yield_mean_t_ha']) * 1000;
      final yMin = asDouble(agro['yield_min_t_ha']) * 1000;
      final yMax = asDouble(agro['yield_max_t_ha']) * 1000;

      final costRow = costById[cropId];
      final costMap = <String, double>{};
      if (costRow != null && costRow['cost_per_ha_php'] is Map) {
        (costRow['cost_per_ha_php'] as Map).forEach((k, v) {
          costMap[k.toString()] = asDouble(v);
        });
      }
      final totalCost = costRow != null
          ? asDouble(costRow['total_cost_per_ha_php'])
          : costMap.values.fold<double>(0, (s, v) => s + v);

      final soil = <String, double>{};
      if (agro['soil_suitability'] is Map) {
        (agro['soil_suitability'] as Map).forEach((k, v) {
          soil[k.toString()] = asDouble(v);
        });
      }

      calibrations[cropId] = CropCalibration(
        cropId: cropId,
        name: asString(agro['name'], cropId),
        category: asString(agro['category']),
        seasons: asStringList(agro['seasons']).map(Season.fromWire).toList(),
        growthDurationDays: asInt(agro['growth_duration_days'], 75),
        baselinePricePerKg: baseline,
        priceP10: p10,
        priceP50: p50,
        priceP90: p90,
        priceCoefficientOfVariation: cov,
        bestPriceUplift:
            baseline == 0 ? 0.15 : ((p90 - baseline) / baseline).clamp(0.05, 0.6),
        worstPriceDrop:
            baseline == 0 ? 0.20 : ((baseline - p10) / baseline).clamp(0.05, 0.6),
        meanYieldKgPerHa: yMean,
        minYieldKgPerHa: yMin,
        maxYieldKgPerHa: yMax,
        bestYieldUplift:
            yMean == 0 ? 0.10 : ((yMax - yMean) / yMean).clamp(0.03, 0.5),
        worstYieldDrop:
            yMean == 0 ? 0.15 : ((yMean - yMin) / yMean).clamp(0.03, 0.5),
        costByCategory: costMap,
        totalCostPerHa: totalCost,
        annualDemandTons: demandById[cropId] == null
            ? 0
            : asDouble(demandById[cropId]!['annual_demand_tons']),
        soilSuitability: soil,
        recentPrices: recent,
      );
    }
    return MarketDataset(calibrations);
  }

  /// Fallback calibration derived from the bundled [CropCatalog] when the JSON
  /// assets cannot be loaded — keeps the app fully functional offline.
  factory MarketDataset.fallback() {
    final map = <String, CropCalibration>{};
    for (final c in CropCatalog.crops) {
      final yMean = c.baselineYieldPerHa;
      map[c.id] = CropCalibration(
        cropId: c.id,
        name: c.name,
        category: c.category,
        seasons: c.suitableSeasons,
        growthDurationDays: c.growthDurationDays,
        baselinePricePerKg: c.baselinePricePerKg,
        priceP10: c.baselinePricePerKg * 0.85,
        priceP50: c.baselinePricePerKg,
        priceP90: c.baselinePricePerKg * 1.15,
        priceCoefficientOfVariation: 0.12,
        bestPriceUplift: 0.15,
        worstPriceDrop: 0.20,
        meanYieldKgPerHa: yMean,
        minYieldKgPerHa: yMean * 0.8,
        maxYieldKgPerHa: yMean * 1.2,
        bestYieldUplift: 0.10,
        worstYieldDrop: 0.15,
        costByCategory: const {'Estimated input cost': 45000},
        totalCostPerHa: 45000,
        annualDemandTons: c.projectedDemandTons,
        soilSuitability: {'loam': c.landSuitabilityScore},
        recentPrices: [c.baselinePricePerKg],
      );
    }
    return MarketDataset(map);
  }

  static double _mean(List<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static double _stdDev(List<double> xs) {
    if (xs.length < 2) return 0;
    final m = _mean(xs);
    final variance =
        xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / xs.length;
    return math.sqrt(variance);
  }

  /// Linear-interpolated percentile (0..100) of an unsorted list.
  static double _percentile(List<double> xs, double p) {
    if (xs.isEmpty) return 0;
    final sorted = [...xs]..sort();
    if (sorted.length == 1) return sorted.first;
    final rank = (p / 100) * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final frac = rank - lo;
    return sorted[lo] + (sorted[hi] - sorted[lo]) * frac;
  }
}
