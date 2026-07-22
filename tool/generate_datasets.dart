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

// ── Varieties (adviser note: variety must be a dropdown, not free text) ───────

/// A locally-planted variety. `maturityOffsetDays` shifts the crop's baseline
/// growth duration — early/late maturing selections within the same crop.
class VarietySpec {
  const VarietySpec(this.name, this.maturityOffsetDays, this.notes);
  final String name;
  final int maturityOffsetDays;
  final String notes;
}

/// Varieties commonly grown in Western Visayas for each reference crop.
const Map<String, List<VarietySpec>> varietiesByCrop = {
  'ampalaya': [
    VarietySpec('Galaxy', 0, 'Hybrid; uniform long green fruit, market standard'),
    VarietySpec('Mayon', -3, 'Early maturing hybrid, good for tight windows'),
    VarietySpec('Jade Star A', 2, 'Vigorous vine, heavier fruit set'),
    VarietySpec('Sta. Rita', 5, 'Open-pollinated; seed can be saved'),
  ],
  'eggplant': [
    VarietySpec('Casino', 0, 'Hybrid; long purple, strong local demand'),
    VarietySpec('Fortuner', -4, 'Early, tolerant to bacterial wilt'),
    VarietySpec('Long Purple', 6, 'Open-pollinated, lower seed cost'),
    VarietySpec('Calibre', 3, 'Firm fruit, holds well in transport'),
  ],
  'okra': [
    VarietySpec('Smooth Green', 0, 'Spineless, standard fresh-market pick'),
    VarietySpec('Green Star', -2, 'Early and uniform'),
    VarietySpec('Lady Finger', 4, 'Slender pod, preferred by some traders'),
  ],
  'string_beans': [
    VarietySpec('Sandigan', 0, 'Long pod, reliable under wet conditions'),
    VarietySpec('Uni-6', -3, 'Early, concentrated set'),
    VarietySpec('Batangas White', 5, 'Open-pollinated, pale pod'),
  ],
  'tomato': [
    VarietySpec('Diamante Max', 0, 'Heat tolerant, firm fruit'),
    VarietySpec('Apollo Improved', -5, 'Early determinate, concentrated harvest'),
    VarietySpec('Marilag', 3, 'Bacterial-wilt tolerant, good for lowland'),
    VarietySpec('Rosalinda', 4, 'Processing type, thicker flesh'),
  ],
  'corn': [
    VarietySpec('Sweet Grande', 0, 'Hybrid sweet corn, high sugar'),
    VarietySpec('Mestizo', 5, 'Widely available hybrid'),
    VarietySpec('IPB Var 6', -4, 'Open-pollinated, seed can be saved'),
  ],
  'squash': [
    VarietySpec('Suprema', 0, 'Hybrid; thick orange flesh'),
    VarietySpec('Rizalina', 4, 'Open-pollinated, long shelf life'),
    VarietySpec('Sunshine', -3, 'Early, smaller fruit'),
  ],
  'pechay': [
    VarietySpec('Black Behi', 0, 'Standard market pechay'),
    VarietySpec('Native Pechay', 3, 'Open-pollinated, hardy'),
    VarietySpec('Snow White', -2, 'Early, white petiole'),
  ],
};

// ── Growth stages (adviser note: "add planting cycle halin sa seedlings") ─────

/// Decomposes a crop's flat growth duration into agronomic stages. The pivot
/// (day 0) is **transplant or direct sowing**; `nurseryDays` is the seedbed
/// period *before* day 0, and is 0 for direct-seeded crops. `vegetativeDays +
/// reproductiveDays` always equals the crop's `growthDays`, so the derived
/// harvest date stays consistent with the existing calibration.
class StageSpec {
  const StageSpec({
    required this.nurseryDays,
    required this.vegetativeDays,
    required this.reproductiveDays,
    required this.harvestWindowDays,
    required this.irrigationIntervalDays,
    required this.sprayIntervalDays,
    required this.basalInput,
    required this.sideDressInput,
    required this.sprayInput,
  });

  final int nurseryDays;
  final int vegetativeDays;
  final int reproductiveDays;

  /// First pick → last pick. 1 for single-harvest crops.
  final int harvestWindowDays;
  final int irrigationIntervalDays;
  final int sprayIntervalDays;
  final String basalInput;
  final String sideDressInput;
  final String sprayInput;

  bool get usesSeedlings => nurseryDays > 0;
}

const Map<String, StageSpec> stagesByCrop = {
  'ampalaya': StageSpec(
    nurseryDays: 0, vegetativeDays: 40, reproductiveDays: 30,
    harvestWindowDays: 45, irrigationIntervalDays: 7, sprayIntervalDays: 10,
    basalInput: 'Complete 14-14-14 + compost',
    sideDressInput: 'Urea 46-0-0',
    sprayInput: 'Cypermethrin / fungicide rotation',
  ),
  'eggplant': StageSpec(
    nurseryDays: 28, vegetativeDays: 45, reproductiveDays: 35,
    harvestWindowDays: 60, irrigationIntervalDays: 7, sprayIntervalDays: 10,
    basalInput: 'Complete 14-14-14 + compost',
    sideDressInput: 'Urea 46-0-0',
    sprayInput: 'Fruit-and-shoot borer control',
  ),
  'okra': StageSpec(
    nurseryDays: 0, vegetativeDays: 35, reproductiveDays: 20,
    harvestWindowDays: 45, irrigationIntervalDays: 7, sprayIntervalDays: 12,
    basalInput: 'Complete 14-14-14',
    sideDressInput: 'Urea 46-0-0',
    sprayInput: 'Aphid / leafhopper control',
  ),
  'string_beans': StageSpec(
    nurseryDays: 0, vegetativeDays: 35, reproductiveDays: 25,
    harvestWindowDays: 30, irrigationIntervalDays: 7, sprayIntervalDays: 12,
    basalInput: 'Complete 14-14-14 (low N — legume fixes nitrogen)',
    sideDressInput: 'Potassium 0-0-60',
    sprayInput: 'Pod borer control',
  ),
  'tomato': StageSpec(
    nurseryDays: 24, vegetativeDays: 45, reproductiveDays: 30,
    harvestWindowDays: 35, irrigationIntervalDays: 6, sprayIntervalDays: 8,
    basalInput: 'Complete 14-14-14 + compost',
    sideDressInput: 'Urea 46-0-0 + calcium nitrate',
    sprayInput: 'Late blight / fruitworm rotation',
  ),
  'corn': StageSpec(
    nurseryDays: 0, vegetativeDays: 55, reproductiveDays: 35,
    harvestWindowDays: 10, irrigationIntervalDays: 10, sprayIntervalDays: 14,
    basalInput: 'Complete 14-14-14',
    sideDressInput: 'Urea 46-0-0',
    sprayInput: 'Corn borer / fall armyworm control',
  ),
  'squash': StageSpec(
    nurseryDays: 0, vegetativeDays: 50, reproductiveDays: 35,
    harvestWindowDays: 30, irrigationIntervalDays: 8, sprayIntervalDays: 12,
    basalInput: 'Complete 14-14-14 + compost',
    sideDressInput: 'Urea 46-0-0',
    sprayInput: 'Fruit fly / powdery mildew control',
  ),
  'pechay': StageSpec(
    nurseryDays: 14, vegetativeDays: 25, reproductiveDays: 10,
    harvestWindowDays: 7, irrigationIntervalDays: 4, sprayIntervalDays: 10,
    basalInput: 'Compost + Complete 14-14-14',
    sideDressInput: 'Urea 46-0-0 (light)',
    sprayInput: 'Diamondback moth control',
  ),
};

// ── Barangay agro-ecology (adviser note: suitability map per barangay) ────────

/// Tubungan is a hilly interior municipality; its barangays span narrow valley
/// floors, rolling midlands, and steep uplands. Terrain drives both the
/// dominant soil and the attainable share of a crop's potential yield.
class TerrainSpec {
  const TerrainSpec(this.label, this.soil, this.yieldFactor);
  final String label;
  final String soil;

  /// Share of the crop's attainable yield reachable on this terrain.
  final double yieldFactor;
}

const Map<String, TerrainSpec> terrains = {
  'lowland': TerrainSpec('Valley floor / lowland', 'clay_loam', 0.95),
  'midland': TerrainSpec('Rolling midland', 'loam', 0.86),
  'upland': TerrainSpec('Upland / hilly', 'sandy_loam', 0.74),
};

/// The 48 barangays of Tubungan, Iloilo — mirrors `AppConstants.barangays`.
const List<String> barangays = [
  'Adgao', 'Ago', 'Ambarihon', 'Ayubo', 'Bacan', 'Bagunanay', 'Badiang',
  'Balicua', 'Bantayanan', 'Zone I (Poblacion)', 'Zone II (Poblacion)',
  'Zone III (Poblacion)', 'Batga', 'Bato', 'Bikil', 'Boloc', 'Bondoc',
  'Borong', 'Buenavista', 'Cadabdab', 'Daga-ay', 'Desposorio',
  'Igdampog Norte', 'Igdampog Sur', 'Igpaho', 'Igtuble', 'Ingay', 'Isauan',
  'Jolason', 'Jona', 'La-ag', 'Lanag Norte', 'Lanag Sur', 'Male', 'Mayang',
  'Molina', 'Morcillas', 'Nagba', 'Navillan', 'Pinamacalan', 'San Jose',
  'Sibucauan', 'Singon', 'Tabat', 'Tagpu-an', 'Talento', 'Teniente Benito',
  'Victoria',
];

/// The three Poblacion zones and the barangays along the valley are treated as
/// lowland; the rest are split midland/upland deterministically. Replace this
/// whole block with the MAO's barangay terrain classification when available.
String terrainFor(String barangay, double roll) {
  if (barangay.contains('Poblacion')) return 'lowland';
  if (roll < 0.28) return 'lowland';
  if (roll < 0.68) return 'midland';
  return 'upland';
}

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

  // ── Varieties ──────────────────────────────────────────────────────────────
  final varieties = <Map<String, dynamic>>[];
  for (final c in crops) {
    for (final v in varietiesByCrop[c.id] ?? const <VarietySpec>[]) {
      varieties.add({
        'crop_id': c.id,
        'variety': v.name,
        'maturity_days': c.growthDays + v.maturityOffsetDays,
        'notes': v.notes,
      });
    }
  }

  // ── Growth stages ──────────────────────────────────────────────────────────
  // Day 0 is transplant (or direct sowing). Nursery days are negative.
  final stages = <Map<String, dynamic>>[];
  for (final c in crops) {
    final s = stagesByCrop[c.id]!;
    void stage(String key, String label, int from, int to) => stages.add({
          'crop_id': c.id,
          'stage': key,
          'label': label,
          'day_from': from,
          'day_to': to,
        });

    if (s.usesSeedlings) {
      stage('nursery', 'Seedling / nursery', -s.nurseryDays, -1);
    }
    stage('establishment',
        s.usesSeedlings ? 'Transplanting' : 'Sowing & emergence', 0, 7);
    stage('vegetative', 'Vegetative growth', 8, s.vegetativeDays);
    stage('reproductive', 'Flowering & fruit set', s.vegetativeDays + 1,
        c.growthDays);
    stage('harvest', 'Harvest window', c.growthDays,
        c.growthDays + s.harvestWindowDays);
  }

  // ── Activity schedule (the agronomic protocol the calendar expands) ────────
  final schedule = <Map<String, dynamic>>[];
  for (final c in crops) {
    final s = stagesByCrop[c.id]!;
    void op(int day, String activity, String title,
        {String input = '', double qty = 0, String unit = ''}) {
      schedule.add({
        'crop_id': c.id,
        'days_after_planting': day,
        'activity_type': activity,
        'title': title,
        'typical_input': input,
        'typical_qty_per_ha': qty,
        'unit': unit,
      });
    }

    // Nursery operations, for crops raised from seedlings.
    if (s.usesSeedlings) {
      op(-s.nurseryDays, 'planting', 'Sow seeds in seedbed',
          input: 'Certified seed', qty: 1, unit: 'packet');
      op(-s.nurseryDays + 7, 'pest_control', 'Drench seedbed against damping-off',
          input: 'Fungicide drench', qty: 0.25, unit: 'L');
      op(-5, 'planting', 'Harden seedlings before transplanting');
    }

    // Land preparation.
    op(-14, 'land_prep', 'Plow and first harrow');
    op(-7, 'land_prep', 'Final harrow, form beds and furrows');

    // Establishment.
    op(0, 'fertilizing', 'Apply basal fertilizer',
        input: s.basalInput, qty: 4, unit: 'bags');
    op(0, 'planting',
        s.usesSeedlings ? 'Transplant seedlings to field' : 'Direct sow in field',
        input: s.usesSeedlings ? 'Hardened seedlings' : 'Certified seed');

    // Irrigation through to the end of the harvest window.
    final lastDay = c.growthDays + s.harvestWindowDays;
    for (var d = s.irrigationIntervalDays;
        d <= lastDay;
        d += s.irrigationIntervalDays) {
      op(d, 'irrigation', 'Irrigate');
    }

    // Weeding + side-dress fertilizer, pegged to the vegetative stage.
    op((s.vegetativeDays * 0.35).round(), 'weeding', 'First weeding / off-barring');
    op((s.vegetativeDays * 0.35).round(), 'fertilizing', 'First side-dress',
        input: s.sideDressInput, qty: 2, unit: 'bags');
    op((s.vegetativeDays * 0.75).round(), 'weeding', 'Second weeding / hilling-up');
    op((s.vegetativeDays * 0.75).round(), 'fertilizing', 'Second side-dress',
        input: s.sideDressInput, qty: 2, unit: 'bags');
    op(s.vegetativeDays + 1, 'fertilizing', 'Flowering-stage fertilizer',
        input: s.sideDressInput, qty: 1, unit: 'bags');

    // Protection sprays from early vegetative to first harvest.
    for (var d = 14; d < c.growthDays; d += s.sprayIntervalDays) {
      op(d, 'pest_control', 'Scheduled protective spray',
          input: s.sprayInput, qty: 0.5, unit: 'L');
    }

    // Fortnightly scouting.
    for (var d = 10; d < c.growthDays; d += 14) {
      op(d, 'scouting', 'Field scouting for pests and disease');
    }

    // Harvest — repeated picks for multi-harvest crops.
    if (s.harvestWindowDays <= 10) {
      op(c.growthDays, 'harvesting', 'Harvest');
    } else {
      var pick = 1;
      for (var d = c.growthDays; d <= lastDay; d += 7) {
        op(d, 'harvesting', 'Harvest — pick $pick');
        pick++;
      }
    }
  }
  schedule.sort((a, b) {
    final c = (a['crop_id'] as String).compareTo(b['crop_id'] as String);
    if (c != 0) return c;
    return (a['days_after_planting'] as int)
        .compareTo(b['days_after_planting'] as int);
  });

  // ── Barangay suitability ───────────────────────────────────────────────────
  // yield_index = share of the crop's attainable yield observed in that
  // barangay = terrain yield factor × the crop's affinity for the terrain's
  // dominant soil (renormalized), with small deterministic variation.
  final suitability = <Map<String, dynamic>>[];
  final terrainRng = _Lcg(20260722);
  final barangayTerrain = <String, String>{
    for (final b in barangays) b: terrainFor(b, terrainRng.next())
  };
  for (final b in barangays) {
    final t = terrains[barangayTerrain[b]!]!;
    final rng = _Lcg(b.codeUnits.fold<int>(13, (a, x) => a * 31 + x) & 0x7fffffff);
    for (final c in crops) {
      // Soil affinity is already 0..1 in the agronomics data; rescale it around
      // the 0.70–0.90 band it occupies so it modulates rather than dominates.
      final affinity = (c.soil[t.soil] ?? 0.8);
      final modulated = 0.85 + (affinity - 0.80) * 1.5;
      final index =
          (t.yieldFactor * modulated * (1 + rng.noise(0.05))).clamp(0.30, 0.98);
      suitability.add({
        'barangay': b,
        'crop_id': c.id,
        'terrain': barangayTerrain[b],
        'dominant_soil': t.soil,
        'yield_index': double.parse(index.toStringAsFixed(3)),
        'observations': 6 + (rng.next() * 18).round(),
        'source_year': 2025,
      });
    }
  }

  // ── Write JSON assets ──────────────────────────────────────────────────────
  _writeJson('assets/data/crop_varieties.json', varieties);
  _writeJson('assets/data/crop_growth_stages.json', stages);
  _writeJson('assets/data/crop_activity_schedule.json', schedule);
  _writeJson('assets/data/barangay_suitability.json', suitability);
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

  // Demand is now monthly — the saturation denominator has to move with the
  // season, not sit at one flat annual figure.
  _writeCsv(
      'datasets/demand_baselines.csv',
      ['crop_id', 'month', 'demand_tons', 'annual_demand_tons', 'source'],
      demand.expand((r) {
        final monthly = (r['monthly_demand_tons'] as List).cast<double>();
        return List.generate(
            12,
            (m) => [
                  r['crop_id'], m + 1, monthly[m], r['annual_demand_tons'],
                  'synthetic_municipal_baseline',
                ]);
      }));

  _writeCsv('datasets/crop_varieties.csv',
      ['crop_id', 'variety', 'maturity_days', 'notes'],
      varieties.map(
          (r) => [r['crop_id'], r['variety'], r['maturity_days'], r['notes']]));

  _writeCsv('datasets/crop_growth_stages.csv',
      ['crop_id', 'stage', 'label', 'day_from', 'day_to'],
      stages.map((r) =>
          [r['crop_id'], r['stage'], r['label'], r['day_from'], r['day_to']]));

  _writeCsv(
      'datasets/crop_activity_schedule.csv',
      ['crop_id', 'days_after_planting', 'activity_type', 'title',
        'typical_input', 'typical_qty_per_ha', 'unit'],
      schedule.map((r) => [
            r['crop_id'], r['days_after_planting'], r['activity_type'],
            r['title'], r['typical_input'], r['typical_qty_per_ha'], r['unit'],
          ]));

  _writeCsv(
      'datasets/barangay_suitability.csv',
      ['barangay', 'crop_id', 'terrain', 'dominant_soil', 'yield_index',
        'observations', 'source_year'],
      suitability.map((r) => [
            r['barangay'], r['crop_id'], r['terrain'], r['dominant_soil'],
            r['yield_index'], r['observations'], r['source_year'],
          ]));

  stdout.writeln('Generated:');
  stdout.writeln('  ${prices.length} monthly price rows '
      '(${crops.length} crops × $years years × 12 months)');
  stdout.writeln('  ${crops.length} agronomic and cost rows each');
  stdout.writeln('  ${crops.length * 12} monthly demand rows');
  stdout.writeln('  ${varieties.length} variety rows');
  stdout.writeln('  ${stages.length} growth-stage rows');
  stdout.writeln('  ${schedule.length} scheduled-activity rows');
  stdout.writeln('  ${suitability.length} barangay×crop suitability rows '
      '(${barangays.length} barangays × ${crops.length} crops)');
  stdout.writeln('Wrote assets/data/*.json and datasets/*.csv');
}

void _writeJson(String path, Object data) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}

/// RFC-4180 cell: quote when the value contains a comma, quote, or newline.
String _csvCell(Object? v) {
  final s = v?.toString() ?? '';
  if (!s.contains(RegExp('[",\n]'))) return s;
  return '"${s.replaceAll('"', '""')}"';
}

void _writeCsv(
    String path, List<String> header, Iterable<List<Object?>> rows) {
  final file = File(path)..createSync(recursive: true);
  final buffer = StringBuffer()..writeln(header.join(','));
  for (final r in rows) {
    buffer.writeln(r.map(_csvCell).join(','));
  }
  file.writeAsStringSync(buffer.toString());
}
