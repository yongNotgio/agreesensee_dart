// Reproducible generator for the AgriSense calibration datasets.
//
// Run with:  dart run tool/generate_datasets.dart
//
// Produces factual-but-synthetic datasets grounded in real Philippine
// (Western Visayas) high-value vegetable economics. Outputs are deterministic
// (seeded), so the same data is reproduced on every run — important for a
// thesis appendix. Two formats are written:
//   • assets/data/*.json  — bundled and loaded by the app at runtime
//   • datasets/*.csv      — human-readable for the manuscript appendix
//
// These calibrate the rule-based decision engines (Objectives 1 & 2); they are
// NOT ML training weights. Baseline prices, price/yield volatility, demand, and
// cost-of-production are derived from these rows by `lib/data/market_dataset.dart`.

import 'dart:convert';
import 'dart:io';

/// Deterministic linear-congruential generator for reproducible "noise".
class _Lcg {
  _Lcg(this.seed);
  int seed;
  double next() {
    seed = (1103515245 * seed + 12345) & 0x7fffffff;
    return seed / 0x7fffffff; // 0..1
  }

  /// Symmetric noise in [-amp, amp].
  double noise(double amp) => (next() * 2 - 1) * amp;
}

/// Per-crop modelling inputs (realistic baselines for the pilot area).
class CropSpec {
  const CropSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.seasons,
    required this.growthDays,
    required this.basePrice,
    required this.priceAmplitude,
    required this.yieldMeanTha,
    required this.yieldMinTha,
    required this.yieldMaxTha,
    required this.annualDemandTons,
    required this.cost,
    required this.soil,
  });

  final String id;
  final String name;
  final String category;
  final List<String> seasons;
  final int growthDays;

  /// Mean farmgate price (PHP/kg) at the series midpoint.
  final double basePrice;

  /// How strongly this crop's price tracks the seasonal index (volatility).
  final double priceAmplitude;

  final double yieldMeanTha;
  final double yieldMinTha;
  final double yieldMaxTha;
  final double annualDemandTons;

  /// Cost of production per hectare (PHP) by category.
  final Map<String, double> cost;

  /// Land suitability (0..1) by soil type.
  final Map<String, double> soil;
}

/// Generic monthly seasonal price index (mean ≈ 1.0). Prices peak during the
/// wet/typhoon lean months (Jul–Sep) and trough during the dry harvest glut
/// (Feb–Apr) — the real pattern AgriSense exists to smooth.
const List<double> seasonalIndex = [
  1.00, 0.90, 0.85, 0.88, 0.98, 1.05, 1.15, 1.20, 1.18, 1.10, 1.02, 1.05,
];

const List<CropSpec> crops = [
  CropSpec(
    id: 'ampalaya',
    name: 'Ampalaya',
    category: 'Vegetable',
    seasons: ['dry', 'wet'],
    growthDays: 70,
    basePrice: 42,
    priceAmplitude: 1.0,
    yieldMeanTha: 12.0,
    yieldMinTha: 9.0,
    yieldMaxTha: 15.0,
    annualDemandTons: 500,
    cost: {
      'seed': 3500,
      'fertilizer': 22000,
      'labor': 45000,
      'irrigation': 8000,
      'pesticide': 12000,
      'transport': 9000,
      'equipment': 18000,
    },
    soil: {'clay_loam': 0.86, 'loam': 0.82, 'sandy_loam': 0.70},
  ),
  CropSpec(
    id: 'eggplant',
    name: 'Eggplant',
    category: 'Vegetable',
    seasons: ['dry', 'wet'],
    growthDays: 80,
    basePrice: 38,
    priceAmplitude: 0.9,
    yieldMeanTha: 18.0,
    yieldMinTha: 14.0,
    yieldMaxTha: 22.0,
    annualDemandTons: 620,
    cost: {
      'seed': 3000,
      'fertilizer': 24000,
      'labor': 42000,
      'irrigation': 8000,
      'pesticide': 13000,
      'transport': 11000,
      'equipment': 9000,
    },
    soil: {'clay_loam': 0.88, 'loam': 0.90, 'sandy_loam': 0.78},
  ),
  CropSpec(
    id: 'okra',
    name: 'Okra',
    category: 'Vegetable',
    seasons: ['dry', 'wet'],
    growthDays: 55,
    basePrice: 35,
    priceAmplitude: 0.9,
    yieldMeanTha: 9.0,
    yieldMinTha: 7.0,
    yieldMaxTha: 11.0,
    annualDemandTons: 410,
    cost: {
      'seed': 2500,
      'fertilizer': 16000,
      'labor': 30000,
      'irrigation': 6000,
      'pesticide': 7000,
      'transport': 7000,
      'equipment': 4000,
    },
    soil: {'clay_loam': 0.82, 'loam': 0.84, 'sandy_loam': 0.80},
  ),
  CropSpec(
    id: 'string_beans',
    name: 'String Beans',
    category: 'Legume',
    seasons: ['dry', 'wet'],
    growthDays: 60,
    basePrice: 50,
    priceAmplitude: 1.0,
    yieldMeanTha: 8.0,
    yieldMinTha: 6.0,
    yieldMaxTha: 10.0,
    annualDemandTons: 360,
    cost: {
      'seed': 4000,
      'fertilizer': 18000,
      'labor': 34000,
      'irrigation': 6000,
      'pesticide': 8000,
      'transport': 7000,
      'equipment': 12000,
    },
    soil: {'clay_loam': 0.84, 'loam': 0.86, 'sandy_loam': 0.82},
  ),
  CropSpec(
    id: 'tomato',
    name: 'Tomato',
    category: 'Vegetable',
    seasons: ['dry'],
    growthDays: 75,
    basePrice: 32,
    priceAmplitude: 1.5, // notoriously volatile
    yieldMeanTha: 20.0,
    yieldMinTha: 15.0,
    yieldMaxTha: 26.0,
    annualDemandTons: 540,
    cost: {
      'seed': 5000,
      'fertilizer': 26000,
      'labor': 40000,
      'irrigation': 9000,
      'pesticide': 15000,
      'transport': 10000,
      'equipment': 8000,
    },
    soil: {'clay_loam': 0.76, 'loam': 0.82, 'sandy_loam': 0.74},
  ),
  CropSpec(
    id: 'corn',
    name: 'Sweet Corn',
    category: 'Cereal',
    seasons: ['wet'],
    growthDays: 90,
    basePrice: 22,
    priceAmplitude: 0.6, // staple, stable
    yieldMeanTha: 6.0,
    yieldMinTha: 4.5,
    yieldMaxTha: 7.5,
    annualDemandTons: 700,
    cost: {
      'seed': 6000,
      'fertilizer': 18000,
      'labor': 22000,
      'irrigation': 5000,
      'pesticide': 5000,
      'transport': 8000,
      'equipment': 3000,
    },
    soil: {'clay_loam': 0.80, 'loam': 0.82, 'sandy_loam': 0.78},
  ),
  CropSpec(
    id: 'squash',
    name: 'Squash',
    category: 'Vegetable',
    seasons: ['dry', 'wet'],
    growthDays: 85,
    basePrice: 24,
    priceAmplitude: 0.7,
    yieldMeanTha: 15.0,
    yieldMinTha: 12.0,
    yieldMaxTha: 18.0,
    annualDemandTons: 480,
    cost: {
      'seed': 3500,
      'fertilizer': 18000,
      'labor': 28000,
      'irrigation': 6000,
      'pesticide': 8000,
      'transport': 10000,
      'equipment': 4000,
    },
    soil: {'clay_loam': 0.83, 'loam': 0.84, 'sandy_loam': 0.80},
  ),
  CropSpec(
    id: 'pechay',
    name: 'Pechay',
    category: 'Leafy Vegetable',
    seasons: ['dry', 'wet'],
    growthDays: 35,
    basePrice: 30,
    priceAmplitude: 1.2, // perishable, swingy
    yieldMeanTha: 11.0,
    yieldMinTha: 9.0,
    yieldMaxTha: 12.5,
    annualDemandTons: 300,
    cost: {
      'seed': 2000,
      'fertilizer': 14000,
      'labor': 24000,
      'irrigation': 5000,
      'pesticide': 5000,
      'transport': 7000,
      'equipment': 2000,
    },
    soil: {'clay_loam': 0.80, 'loam': 0.82, 'sandy_loam': 0.78},
  ),
];

const int years = 3;
const int startYear = 2023;

void main() {
  final agronomics = <Map<String, dynamic>>[];
  final costs = <Map<String, dynamic>>[];
  final prices = <Map<String, dynamic>>[];
  final demand = <Map<String, dynamic>>[];

  for (final c in crops) {
    agronomics.add({
      'crop_id': c.id,
      'name': c.name,
      'category': c.category,
      'seasons': c.seasons,
      'growth_duration_days': c.growthDays,
      'yield_mean_t_ha': c.yieldMeanTha,
      'yield_min_t_ha': c.yieldMinTha,
      'yield_max_t_ha': c.yieldMaxTha,
      'soil_suitability': c.soil,
    });

    final total = c.cost.values.fold<double>(0, (s, v) => s + v);
    costs.add({
      'crop_id': c.id,
      'cost_per_ha_php': c.cost,
      'total_cost_per_ha_php': total,
    });

    demand.add({
      'crop_id': c.id,
      'annual_demand_tons': c.annualDemandTons,
      // Demand is fairly steady with mild festive bumps (May, Dec).
      'monthly_demand_tons': List.generate(12, (m) {
        final festive = (m == 4 || m == 11) ? 1.12 : 1.0;
        return double.parse(
            (c.annualDemandTons / 12 * festive).toStringAsFixed(2));
      }),
    });

    // Seed the noise per crop so each series is reproducible but distinct.
    final rng = _Lcg(c.id.codeUnits.fold<int>(7, (a, b) => a + b));
    for (var y = 0; y < years; y++) {
      // Gentle ~4%/yr upward (inflation) trend.
      final trend = 1 + 0.04 * y;
      for (var m = 0; m < 12; m++) {
        final seasonal = 1 + c.priceAmplitude * (seasonalIndex[m] - 1);
        final price = c.basePrice * trend * seasonal * (1 + rng.noise(0.03));
        prices.add({
          'crop_id': c.id,
          'year': startYear + y,
          'month': m + 1,
          'price_per_kg': double.parse(price.toStringAsFixed(2)),
        });
      }
    }
  }

  // ── Write JSON assets ──────────────────────────────────────────────────────
  _writeJson('assets/data/crop_agronomics.json', agronomics);
  _writeJson('assets/data/production_costs.json', costs);
  _writeJson('assets/data/market_prices_monthly.json', prices);
  _writeJson('assets/data/demand_baselines.json', demand);

  // ── Write CSV (thesis appendix) ────────────────────────────────────────────
  _writeCsv('datasets/market_prices_monthly.csv',
      ['crop_id', 'year', 'month', 'price_per_kg'],
      prices.map((r) => [r['crop_id'], r['year'], r['month'], r['price_per_kg']]));

  _writeCsv(
      'datasets/production_costs.csv',
      ['crop_id', 'seed', 'fertilizer', 'labor', 'irrigation', 'pesticide',
        'transport', 'equipment', 'total_per_ha'],
      crops.map((c) => [
            c.id, c.cost['seed'], c.cost['fertilizer'], c.cost['labor'],
            c.cost['irrigation'], c.cost['pesticide'], c.cost['transport'],
            c.cost['equipment'], c.cost.values.fold<double>(0, (s, v) => s + v),
          ]));

  _writeCsv(
      'datasets/crop_agronomics.csv',
      ['crop_id', 'name', 'category', 'seasons', 'growth_days',
        'yield_mean_t_ha', 'yield_min_t_ha', 'yield_max_t_ha',
        'soil_clay_loam', 'soil_loam', 'soil_sandy_loam'],
      crops.map((c) => [
            c.id, c.name, c.category, c.seasons.join('|'), c.growthDays,
            c.yieldMeanTha, c.yieldMinTha, c.yieldMaxTha,
            c.soil['clay_loam'], c.soil['loam'], c.soil['sandy_loam'],
          ]));

  _writeCsv('datasets/demand_baselines.csv', ['crop_id', 'annual_demand_tons'],
      crops.map((c) => [c.id, c.annualDemandTons]));

  stdout.writeln('Generated:');
  stdout.writeln('  ${prices.length} monthly price rows '
      '(${crops.length} crops × $years years × 12 months)');
  stdout.writeln('  ${crops.length} agronomic, cost, and demand rows each');
  stdout.writeln('Wrote assets/data/*.json and datasets/*.csv');
}

void _writeJson(String path, Object data) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}

void _writeCsv(
    String path, List<String> header, Iterable<List<Object?>> rows) {
  final file = File(path)..createSync(recursive: true);
  final buffer = StringBuffer()..writeln(header.join(','));
  for (final r in rows) {
    buffer.writeln(r.map((v) => v?.toString() ?? '').join(','));
  }
  file.writeAsStringSync(buffer.toString());
}
