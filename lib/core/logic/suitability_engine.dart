import '../../data/agronomy_dataset.dart';
import '../../models/enums.dart';
import '../constants/app_constants.dart';

/// Land suitability of one crop in one barangay, banded for display.
class SuitabilityResult {
  const SuitabilityResult({
    required this.barangay,
    required this.cropId,
    required this.yieldIndex,
    required this.band,
    required this.terrain,
    required this.dominantSoil,
    required this.observations,
    required this.isMapped,
  });

  final String barangay;
  final String cropId;

  /// Observed yield as a share of the crop's attainable yield (0..1).
  final double yieldIndex;
  final SuitabilityBand band;
  final String terrain;
  final String dominantSoil;
  final int observations;

  /// False when the barangay/crop pair has no row and the value was inferred
  /// from the crop's generic soil affinity instead.
  final bool isMapped;

  String get cropName => CropCatalog.nameFor(cropId);

  int get percent => (yieldIndex * 100).round();

  /// Expected yield in kg/ha for this barangay: the crop's attainable mean
  /// scaled by how well it actually performs here.
  double expectedYieldPerHa(double attainableYieldPerHa) =>
      attainableYieldPerHa * yieldIndex;

  String get rationale {
    final where = terrain.isEmpty ? barangay : '$barangay ($terrain)';
    return switch (band) {
      SuitabilityBand.verySuitable =>
        '$cropName performs very well in $where — around $percent% of its '
            'attainable yield.',
      SuitabilityBand.suitable =>
        '$cropName grows well in $where, reaching about $percent% of its '
            'attainable yield.',
      SuitabilityBand.moderate =>
        '$cropName is workable in $where but only reaches about $percent% of '
            'its attainable yield. Expect a lighter harvest.',
      SuitabilityBand.marginal =>
        '$cropName is poorly matched to $where — about $percent% of attainable '
            'yield. Consider a better-suited crop.',
    };
  }
}

/// Scores how well each crop suits a given barangay (adviser note: land
/// suitability map).
///
/// The barangay a farmer plants in was collected everywhere in the app and read
/// by nothing — every farmer in the municipality saw an identical crop ranking.
/// This engine makes location matter.
///
/// Bands are cut on the **yield index** — observed yield as a share of the
/// crop's attainable yield — using the thresholds on [SuitabilityBand].
class SuitabilityEngine {
  const SuitabilityEngine._();

  /// Suitability of one crop in one barangay.
  ///
  /// Falls back to the crop's generic soil affinity when the pair is unmapped,
  /// flagging the result as inferred so the UI can be honest about it.
  static SuitabilityResult forCrop({
    required String barangay,
    required String cropId,
    required AgronomyDataset agronomy,
    double? fallbackSoilScore,
  }) {
    final row = agronomy.suitability(barangay, cropId);
    if (row != null) {
      return SuitabilityResult(
        barangay: barangay,
        cropId: cropId,
        yieldIndex: row.yieldIndex,
        band: row.band,
        terrain: row.terrain,
        dominantSoil: row.dominantSoil,
        observations: row.observations,
        isMapped: true,
      );
    }
    final inferred = fallbackSoilScore ??
        CropCatalog.byIdOrFirst(cropId).landSuitabilityScore;
    return SuitabilityResult(
      barangay: barangay,
      cropId: cropId,
      yieldIndex: inferred,
      band: SuitabilityBand.forIndex(inferred),
      terrain: '',
      dominantSoil: '',
      observations: 0,
      isMapped: false,
    );
  }

  /// Every catalog crop ranked for a barangay, most suitable first — the list a
  /// farmer should see *before* deciding what to declare.
  static List<SuitabilityResult> rankCropsForBarangay({
    required String barangay,
    required AgronomyDataset agronomy,
  }) {
    final results = CropCatalog.crops
        .map((c) => forCrop(
              barangay: barangay,
              cropId: c.id,
              agronomy: agronomy,
            ))
        .toList()
      ..sort((a, b) => b.yieldIndex.compareTo(a.yieldIndex));
    return results;
  }

  /// Every barangay ranked for one crop, best first — "where does this grow
  /// best?" rather than "what should I grow here?".
  static List<SuitabilityResult> rankBarangaysForCrop({
    required String cropId,
    required AgronomyDataset agronomy,
  }) {
    return agronomy
        .rankedForCrop(cropId)
        .map((r) => SuitabilityResult(
              barangay: r.barangay,
              cropId: r.cropId,
              yieldIndex: r.yieldIndex,
              band: r.band,
              terrain: r.terrain,
              dominantSoil: r.dominantSoil,
              observations: r.observations,
              isMapped: true,
            ))
        .toList();
  }

  /// A crop × barangay grid for the heat-map view. Rows are barangays (the
  /// farmer's own first, then the rest alphabetically), columns are crops.
  static SuitabilityMatrix matrix({
    required AgronomyDataset agronomy,
    String? focusBarangay,
    List<String>? barangays,
  }) {
    final cropIds = CropCatalog.crops.map((c) => c.id).toList();
    final rows = barangays ?? agronomy.barangays;
    final ordered = [...rows];
    if (focusBarangay != null && ordered.remove(focusBarangay)) {
      ordered.insert(0, focusBarangay);
    }
    return SuitabilityMatrix(
      barangays: ordered,
      cropIds: cropIds,
      values: {
        for (final b in ordered)
          b: {
            for (final c in cropIds)
              c: forCrop(barangay: b, cropId: c, agronomy: agronomy)
          }
      },
    );
  }
}

/// A crop × barangay suitability grid.
class SuitabilityMatrix {
  const SuitabilityMatrix({
    required this.barangays,
    required this.cropIds,
    required this.values,
  });

  final List<String> barangays;
  final List<String> cropIds;
  final Map<String, Map<String, SuitabilityResult>> values;

  SuitabilityResult? at(String barangay, String cropId) =>
      values[barangay]?[cropId];

  bool get isEmpty => barangays.isEmpty || cropIds.isEmpty;
}
