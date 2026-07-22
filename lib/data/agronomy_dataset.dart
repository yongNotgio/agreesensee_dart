import '../core/utils/parsing.dart';
import '../models/enums.dart';

/// A locally-grown variety of a reference crop (`crop_varieties` dataset).
///
/// Variety used to be free text, which made the field unusable for analysis —
/// twelve spellings of the same variety cannot be aggregated. It is now a
/// bounded choice, and each variety carries its own maturity period so an
/// early-maturing selection produces an earlier harvest date.
class CropVariety {
  const CropVariety({
    required this.cropId,
    required this.name,
    required this.maturityDays,
    this.notes = '',
  });

  final String cropId;
  final String name;

  /// Days from transplant/sowing to first harvest for this specific variety.
  final int maturityDays;
  final String notes;

  factory CropVariety.fromMap(Map<String, dynamic> map) => CropVariety(
        cropId: asString(map['crop_id']),
        name: asString(map['variety']),
        maturityDays: asInt(map['maturity_days'], 75),
        notes: asString(map['notes']),
      );
}

/// One stage in a crop's growth cycle (`crop_growth_stages` dataset).
///
/// Day 0 is transplant (or direct sowing); nursery stages carry negative days.
/// This is what makes "planting cycle halin sa seedlings" representable — a
/// single flat growth-duration number cannot express a seedbed period.
class GrowthStage {
  const GrowthStage({
    required this.cropId,
    required this.stage,
    required this.label,
    required this.dayFrom,
    required this.dayTo,
  });

  final String cropId;
  final String stage;
  final String label;
  final int dayFrom;
  final int dayTo;

  factory GrowthStage.fromMap(Map<String, dynamic> map) => GrowthStage(
        cropId: asString(map['crop_id']),
        stage: asString(map['stage']),
        label: asString(map['label']),
        dayFrom: asInt(map['day_from']),
        dayTo: asInt(map['day_to']),
      );

  bool get isNursery => stage == 'nursery';
  int get durationDays => dayTo - dayFrom + 1;
}

/// A scheduled farm operation in a crop's agronomic protocol
/// (`crop_activity_schedule` dataset) — the raw material the crop calendar
/// expands into dated, per-declaration tasks.
class ScheduledOperation {
  const ScheduledOperation({
    required this.cropId,
    required this.daysAfterPlanting,
    required this.activity,
    required this.title,
    this.input = '',
    this.qtyPerHa = 0,
    this.unit = '',
  });

  final String cropId;

  /// Offset from day 0. Negative for nursery and land-preparation operations.
  final int daysAfterPlanting;
  final ActivityType activity;
  final String title;
  final String input;
  final double qtyPerHa;
  final String unit;

  factory ScheduledOperation.fromMap(Map<String, dynamic> map) =>
      ScheduledOperation(
        cropId: asString(map['crop_id']),
        daysAfterPlanting: asInt(map['days_after_planting']),
        activity: ActivityType.fromWire(asStringOrNull(map['activity_type'])),
        title: asString(map['title']),
        input: asString(map['typical_input']),
        qtyPerHa: asDouble(map['typical_qty_per_ha']),
        unit: asString(map['unit']),
      );
}

/// Observed suitability of one crop in one barangay
/// (`barangay_suitability` dataset).
class BarangaySuitability {
  const BarangaySuitability({
    required this.barangay,
    required this.cropId,
    required this.yieldIndex,
    this.terrain = '',
    this.dominantSoil = '',
    this.observations = 0,
    this.sourceYear = 0,
  });

  final String barangay;
  final String cropId;

  /// Observed yield as a share of the crop's attainable yield (0..1). This is
  /// the quantity the suitability bands are cut on.
  final double yieldIndex;

  final String terrain;
  final String dominantSoil;
  final int observations;
  final int sourceYear;

  factory BarangaySuitability.fromMap(Map<String, dynamic> map) =>
      BarangaySuitability(
        barangay: asString(map['barangay']),
        cropId: asString(map['crop_id']),
        yieldIndex: asDouble(map['yield_index']),
        terrain: asString(map['terrain']),
        dominantSoil: asString(map['dominant_soil']),
        observations: asInt(map['observations']),
        sourceYear: asInt(map['source_year']),
      );

  SuitabilityBand get band => SuitabilityBand.forIndex(yieldIndex);

  int get percent => (yieldIndex * 100).round();
}

/// The parsed agronomy reference data: varieties, growth stages, the activity
/// protocol, and the barangay suitability map.
///
/// Kept separate from `MarketDataset` (price/cost/demand calibration) because
/// this half describes *how a crop is grown and where it grows well*, while
/// that half describes *what it is worth*.
class AgronomyDataset {
  const AgronomyDataset({
    required this.varietiesByCrop,
    required this.stagesByCrop,
    required this.scheduleByCrop,
    required this.suitabilityByBarangay,
  });

  final Map<String, List<CropVariety>> varietiesByCrop;
  final Map<String, List<GrowthStage>> stagesByCrop;
  final Map<String, List<ScheduledOperation>> scheduleByCrop;

  /// barangay → (crop id → suitability).
  final Map<String, Map<String, BarangaySuitability>> suitabilityByBarangay;

  static const AgronomyDataset empty = AgronomyDataset(
    varietiesByCrop: {},
    stagesByCrop: {},
    scheduleByCrop: {},
    suitabilityByBarangay: {},
  );

  bool get isEmpty => varietiesByCrop.isEmpty && suitabilityByBarangay.isEmpty;

  List<CropVariety> varietiesFor(String cropId) =>
      varietiesByCrop[cropId] ?? const [];

  CropVariety? variety(String cropId, String name) {
    for (final v in varietiesFor(cropId)) {
      if (v.name == name) return v;
    }
    return null;
  }

  List<GrowthStage> stagesFor(String cropId) => stagesByCrop[cropId] ?? const [];

  List<ScheduledOperation> scheduleFor(String cropId) =>
      scheduleByCrop[cropId] ?? const [];

  /// Nursery period in days for a crop, or 0 when it is direct-seeded.
  int nurseryDaysFor(String cropId) {
    for (final s in stagesFor(cropId)) {
      if (s.isNursery) return -s.dayFrom;
    }
    return 0;
  }

  bool usesSeedlings(String cropId) => nurseryDaysFor(cropId) > 0;

  BarangaySuitability? suitability(String barangay, String cropId) =>
      suitabilityByBarangay[barangay]?[cropId];

  /// Suitability index for a crop in a barangay, or null when unmapped.
  double? indexFor(String barangay, String cropId) =>
      suitability(barangay, cropId)?.yieldIndex;

  /// All crops ranked by suitability within a barangay, best first.
  List<BarangaySuitability> rankedForBarangay(String barangay) {
    final rows = suitabilityByBarangay[barangay]?.values.toList() ?? [];
    rows.sort((a, b) => b.yieldIndex.compareTo(a.yieldIndex));
    return rows;
  }

  /// All barangays ranked by how well they grow one crop, best first.
  List<BarangaySuitability> rankedForCrop(String cropId) {
    final rows = <BarangaySuitability>[];
    for (final byCrop in suitabilityByBarangay.values) {
      final row = byCrop[cropId];
      if (row != null) rows.add(row);
    }
    rows.sort((a, b) => b.yieldIndex.compareTo(a.yieldIndex));
    return rows;
  }

  List<String> get barangays {
    final list = suitabilityByBarangay.keys.toList()..sort();
    return list;
  }

  factory AgronomyDataset.fromJson({
    required List<dynamic> varieties,
    required List<dynamic> stages,
    required List<dynamic> schedule,
    required List<dynamic> suitability,
  }) {
    final varietyMap = <String, List<CropVariety>>{};
    for (final r in varieties.cast<Map<String, dynamic>>()) {
      final v = CropVariety.fromMap(r);
      varietyMap.putIfAbsent(v.cropId, () => []).add(v);
    }

    final stageMap = <String, List<GrowthStage>>{};
    for (final r in stages.cast<Map<String, dynamic>>()) {
      final s = GrowthStage.fromMap(r);
      stageMap.putIfAbsent(s.cropId, () => []).add(s);
    }
    for (final list in stageMap.values) {
      list.sort((a, b) => a.dayFrom.compareTo(b.dayFrom));
    }

    final scheduleMap = <String, List<ScheduledOperation>>{};
    for (final r in schedule.cast<Map<String, dynamic>>()) {
      final o = ScheduledOperation.fromMap(r);
      scheduleMap.putIfAbsent(o.cropId, () => []).add(o);
    }
    for (final list in scheduleMap.values) {
      list.sort((a, b) => a.daysAfterPlanting.compareTo(b.daysAfterPlanting));
    }

    final suitabilityMap = <String, Map<String, BarangaySuitability>>{};
    for (final r in suitability.cast<Map<String, dynamic>>()) {
      final s = BarangaySuitability.fromMap(r);
      suitabilityMap.putIfAbsent(s.barangay, () => {})[s.cropId] = s;
    }

    return AgronomyDataset(
      varietiesByCrop: varietyMap,
      stagesByCrop: stageMap,
      scheduleByCrop: scheduleMap,
      suitabilityByBarangay: suitabilityMap,
    );
  }
}
