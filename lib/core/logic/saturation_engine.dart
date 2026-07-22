import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../constants/app_constants.dart';

/// A demand figure plus where it came from, so the Saturation Index can say
/// what it divided by rather than presenting an anonymous number.
class DemandFigure {
  const DemandFigure({
    required this.tons,
    required this.source,
    this.contributorCount = 0,
  });

  final double tons;
  final DemandSource source;

  /// How many cooperatives declared this demand ([DemandSource.cooperative]).
  final int contributorCount;

  static const DemandFigure none =
      DemandFigure(tons: 0, source: DemandSource.catalog);

  String get provenance => switch (source) {
        DemandSource.cooperative =>
          'declared by $contributorCount cooperative(s)',
        DemandSource.baseline => 'municipal monthly baseline',
        DemandSource.catalog => 'catalog fallback',
      };
}

/// Result of a Market Saturation Index computation for one crop.
///
/// Compares **expected supply** (the sum of active declarations' projected
/// yields) against **market demand**, and bands the ratio into low / moderate /
/// high oversupply risk.
class SaturationResult {
  const SaturationResult({
    required this.cropId,
    required this.expectedSupplyTons,
    required this.demand,
    required this.index,
    required this.level,
    required this.contributingDeclarations,
  });

  final String cropId;
  final double expectedSupplyTons;
  final DemandFigure demand;

  /// Saturation Index = expected supply ÷ market demand.
  final double index;
  final SaturationLevel level;
  final int contributingDeclarations;

  String get cropName => CropCatalog.nameFor(cropId);

  double get demandTons => demand.tons;
  DemandSource get demandSource => demand.source;

  /// Surplus above demand, in tons (0 when supply ≤ demand).
  double get surplusTons =>
      (expectedSupplyTons - demandTons).clamp(0, double.infinity);

  double get demandFillRatio => demandTons <= 0 ? 0 : index;
}

/// One cell of the crop × month saturation heat map.
class SaturationCell {
  const SaturationCell({
    required this.cropId,
    required this.month,
    required this.year,
    required this.supplyTons,
    required this.demandTons,
    required this.index,
    required this.level,
  });

  final String cropId;
  final int month;
  final int year;
  final double supplyTons;
  final double demandTons;
  final double index;
  final SaturationLevel level;
}

/// A crop × month saturation grid over a rolling horizon.
class SaturationMatrix {
  const SaturationMatrix({
    required this.cropIds,
    required this.months,
    required this.cells,
  });

  final List<String> cropIds;

  /// The first day of each month in the horizon, in order.
  final List<DateTime> months;

  /// crop id → month key (`yyyy-MM`) → cell.
  final Map<String, Map<String, SaturationCell>> cells;

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  SaturationCell? at(String cropId, DateTime month) =>
      cells[cropId]?[monthKey(month)];

  bool get isEmpty => cropIds.isEmpty || months.isEmpty;
}

/// Pure functions computing the Market Saturation Index.
class SaturationEngine {
  const SaturationEngine._();

  /// Band thresholds on the supply/demand ratio.
  ///   index < 0.85           → low risk
  ///   0.85 ≤ index ≤ 1.15    → moderate risk (near balance)
  ///   index > 1.15           → high oversupply risk
  static const double lowCeiling = 0.85;
  static const double highFloor = 1.15;

  static SaturationLevel levelForIndex(double index) {
    if (index < lowCeiling) return SaturationLevel.low;
    if (index > highFloor) return SaturationLevel.high;
    return SaturationLevel.moderate;
  }

  /// Compute saturation for a single crop from active declarations.
  ///
  /// [demandOverride] carries the resolved demand figure and its provenance —
  /// cooperative-declared where available, else the monthly baseline.
  static SaturationResult forCrop({
    required String cropId,
    required List<CropDeclaration> declarations,
    DemandFigure? demandOverride,
  }) {
    final relevant = declarations
        .where((d) => d.cropId == cropId && d.status.isActive)
        .toList();
    final supply =
        relevant.fold<double>(0, (sum, d) => sum + d.expectedYieldTons);
    final demand = demandOverride ??
        DemandFigure(
          tons: CropCatalog.byIdOrFirst(cropId).projectedDemandTons,
          source: DemandSource.catalog,
        );
    final index = demand.tons <= 0 ? 0.0 : supply / demand.tons;
    return SaturationResult(
      cropId: cropId,
      expectedSupplyTons: supply,
      demand: demand,
      index: index,
      level: levelForIndex(index),
      contributingDeclarations: relevant.length,
    );
  }

  /// Compute saturation for every crop in the catalog plus any extra crop
  /// present in [declarations].
  static List<SaturationResult> forAllCrops(
    List<CropDeclaration> declarations, {
    Map<String, DemandFigure>? demandOverrides,
  }) {
    final cropIds = <String>{
      ...CropCatalog.crops.map((c) => c.id),
      ...declarations.map((d) => d.cropId),
    };
    final results = cropIds
        .map((id) => forCrop(
              cropId: id,
              declarations: declarations,
              demandOverride: demandOverrides?[id],
            ))
        .toList()
      ..sort((a, b) => b.index.compareTo(a.index));
    return results;
  }

  /// Build a crop × month saturation grid over [months] months from [from].
  ///
  /// Supply lands in the month a declaration is expected to be harvested, and
  /// is compared against that month's demand — because the same tonnage is a
  /// glut in the harvest peak and a shortfall in the lean season.
  static SaturationMatrix monthlyMatrix({
    required List<CropDeclaration> declarations,
    required double Function(String cropId, int month) monthlyDemand,
    DateTime? from,
    int months = 12,
  }) {
    final start = from ?? DateTime.now();
    final horizon = List.generate(
      months,
      (i) => DateTime(start.year, start.month + i, 1),
    );
    final cropIds = <String>{
      ...CropCatalog.crops.map((c) => c.id),
      ...declarations.map((d) => d.cropId),
    }.toList();

    // Bucket expected supply into the month of expected harvest.
    final supply = <String, Map<String, double>>{};
    for (final d in declarations) {
      if (!d.status.isActive) continue;
      final key = SaturationMatrix.monthKey(d.expectedHarvestDate);
      supply.putIfAbsent(d.cropId, () => {});
      supply[d.cropId]![key] = (supply[d.cropId]![key] ?? 0) + d.expectedYieldTons;
    }

    final cells = <String, Map<String, SaturationCell>>{};
    for (final cropId in cropIds) {
      cells[cropId] = {};
      for (final m in horizon) {
        final key = SaturationMatrix.monthKey(m);
        final s = supply[cropId]?[key] ?? 0;
        final dem = monthlyDemand(cropId, m.month);
        final index = dem <= 0 ? 0.0 : s / dem;
        cells[cropId]![key] = SaturationCell(
          cropId: cropId,
          month: m.month,
          year: m.year,
          supplyTons: s,
          demandTons: dem,
          index: index,
          level: levelForIndex(index),
        );
      }
    }

    return SaturationMatrix(
      cropIds: cropIds,
      months: horizon,
      cells: cells,
    );
  }

  /// Expected supply in tons per crop per barangay — the concentration view
  /// showing where a crop is being planted heavily.
  static Map<String, Map<String, double>> supplyByBarangay(
    List<CropDeclaration> declarations,
  ) {
    final map = <String, Map<String, double>>{};
    for (final d in declarations) {
      if (!d.status.isActive) continue;
      map.putIfAbsent(d.barangay, () => {});
      map[d.barangay]![d.cropId] =
          (map[d.barangay]![d.cropId] ?? 0) + d.expectedYieldTons;
    }
    return map;
  }
}
