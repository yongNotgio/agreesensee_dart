import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../constants/app_constants.dart';

/// Result of a Market Saturation Index computation for one crop.
///
/// Implements Phase 5 of the workflow: compare **expected supply** (the sum of
/// approved/active declarations' projected yields) against **market demand**
/// and band the ratio into low / moderate / high oversupply risk.
class SaturationResult {
  const SaturationResult({
    required this.cropId,
    required this.expectedSupplyTons,
    required this.demandTons,
    required this.index,
    required this.level,
    required this.contributingDeclarations,
  });

  final String cropId;
  final double expectedSupplyTons;
  final double demandTons;

  /// Saturation Index = expected supply ÷ market demand.
  final double index;
  final SaturationLevel level;
  final int contributingDeclarations;

  String get cropName => CropCatalog.nameFor(cropId);

  /// Surplus above demand, in tons (0 when supply ≤ demand).
  double get surplusTons =>
      (expectedSupplyTons - demandTons).clamp(0, double.infinity);

  double get demandFillRatio => demandTons <= 0 ? 0 : index;
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
  /// [demandOverride] lets the cooperative/MAO supply a locally-observed demand
  /// figure; otherwise the crop catalog baseline is used.
  static SaturationResult forCrop({
    required String cropId,
    required List<CropDeclaration> declarations,
    double? demandOverride,
  }) {
    final relevant = declarations
        .where((d) => d.cropId == cropId && d.status.isActive)
        .toList();
    final supply =
        relevant.fold<double>(0, (sum, d) => sum + d.expectedYieldTons);
    final demand =
        demandOverride ?? CropCatalog.byIdOrFirst(cropId).projectedDemandTons;
    final index = demand <= 0 ? 0.0 : supply / demand;
    return SaturationResult(
      cropId: cropId,
      expectedSupplyTons: supply,
      demandTons: demand,
      index: index,
      level: levelForIndex(index),
      contributingDeclarations: relevant.length,
    );
  }

  /// Compute saturation for every crop present in [declarations], plus the full
  /// catalog (so planners see crops with zero current supply too).
  static List<SaturationResult> forAllCrops(
    List<CropDeclaration> declarations, {
    Map<String, double>? demandOverrides,
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
}
