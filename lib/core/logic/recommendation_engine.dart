import '../../data/agronomy_dataset.dart';
import '../../data/market_dataset.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/farm.dart';
import '../constants/app_constants.dart';
import 'saturation_engine.dart';
import 'scenario_engine.dart';
import 'suitability_engine.dart';

/// A ranked crop recommendation with an explainable score breakdown.
class CropRecommendation {
  const CropRecommendation({
    required this.crop,
    required this.score,
    required this.suitabilityScore,
    required this.seasonScore,
    required this.saturationScore,
    required this.profitabilityScore,
    required this.saturation,
    required this.suitability,
    required this.projectedNetPerHa,
    required this.expectedYieldPerHa,
    required this.baselinePricePerKg,
    required this.rationale,
  });

  final CropProfile crop;

  /// Composite 0–1 desirability score.
  final double score;
  final double suitabilityScore;
  final double seasonScore;
  final double saturationScore;
  final double profitabilityScore;
  final SaturationResult saturation;

  /// Barangay-level land suitability, when a barangay is known.
  final SuitabilityResult? suitability;

  final double projectedNetPerHa;

  /// System-derived expected yield for this crop here (kg/ha) — the figure the
  /// farmer used to be asked to guess.
  final double expectedYieldPerHa;
  final double baselinePricePerKg;

  final String rationale;

  int get scorePercent => (score * 100).round();
  bool get isHighlyRecommended => score >= 0.7;
}

/// An intercropping (mix-and-match) pairing recommendation.
class IntercropRecommendation {
  const IntercropRecommendation({
    required this.primary,
    required this.companion,
    required this.combinedScore,
    required this.rationale,
  });

  final CropProfile primary;
  final CropProfile companion;
  final double combinedScore;
  final String rationale;
}

/// How risky a specific planting plan looks *before* the farmer commits to it.
enum RiskVerdict {
  low('low', 'Low Risk'),
  caution('caution', 'Proceed with Caution'),
  high('high', 'High Risk');

  const RiskVerdict(this.wire, this.label);
  final String wire;
  final String label;

  static RiskVerdict fromWire(String? value) => RiskVerdict.values.firstWhere(
        (v) => v.wire == value,
        orElse: () => RiskVerdict.caution,
      );
}

/// The pre-declaration assessment shown while a farmer fills in the form.
///
/// With the MAO approval chain removed, this is the **only** guardrail between
/// a farmer and planting into a glut — so it has to be visible at the moment of
/// the decision, not buried in a separate advisory tab.
class DeclarationRisk {
  const DeclarationRisk({
    required this.verdict,
    required this.reasons,
    required this.suitability,
    required this.saturation,
    required this.expectedYieldKg,
    required this.projectedPricePerKg,
    required this.bestCaseRevenue,
    required this.worstCaseRevenue,
    required this.alternatives,
  });

  final RiskVerdict verdict;

  /// Plain-language reasons behind the verdict, most important first.
  final List<String> reasons;

  final SuitabilityResult? suitability;
  final SaturationResult saturation;

  /// System-derived expectations for the parcel being declared.
  final double expectedYieldKg;
  final double projectedPricePerKg;

  /// Revenue under favourable and adverse price/yield movements, from the
  /// crop's own 3-year distribution. Forward-looking figures belong here — at
  /// the decision point — rather than on a declaration already committed to.
  final double bestCaseRevenue;
  final double worstCaseRevenue;

  /// Better-scoring crops to offer when the verdict is [RiskVerdict.high].
  final List<CropRecommendation> alternatives;

  double get projectedRevenue => expectedYieldKg * projectedPricePerKg;

  bool get isHigh => verdict == RiskVerdict.high;

  /// True when the crop's own history shows a wide enough spread to be worth
  /// warning about.
  bool get hasVolatilityBand =>
      bestCaseRevenue > worstCaseRevenue && worstCaseRevenue > 0;
}

/// Weighted, explainable crop recommendation engine.
///
/// Blends four normalized signals — land suitability (barangay-specific where
/// mapped), seasonal fit, market saturation (inverse), and projected
/// profitability — into a single score. Pure, deterministic, and offline.
class RecommendationEngine {
  const RecommendationEngine._();

  // Signal weights (sum = 1.0).
  static const double wSuitability = 0.25;
  static const double wSeason = 0.20;
  static const double wSaturation = 0.30; // oversupply avoidance is paramount
  static const double wProfit = 0.25;

  /// Assumed input cost per hectare used to normalize profitability when the
  /// dataset has no cost-of-production row (₱ per ha).
  static const double assumedCostPerHa = 45000;

  static List<CropRecommendation> recommend({
    required Farm? farm,
    required List<CropDeclaration> allDeclarations,
    Season? season,
    String? barangay,
    Map<String, DemandFigure>? demandOverrides,
    Map<String, CropCalibration>? calibration,
    AgronomyDataset agronomy = AgronomyDataset.empty,
  }) {
    final activeSeason = season ?? Season.forMonth(DateTime.now().month);
    final area = barangay ?? farm?.barangay;

    double netPerHaFor(CropProfile crop) {
      final cal = calibration?[crop.id];
      if (cal != null) return cal.projectedNetPerHa;
      final revenue = crop.baselineYieldPerHa * crop.baselinePricePerKg;
      return revenue - assumedCostPerHa;
    }

    final netPerHaByCrop = {
      for (final c in CropCatalog.crops) c.id: netPerHaFor(c)
    };
    final maxNet = netPerHaByCrop.values
        .fold<double>(1, (m, v) => v > m ? v : m)
        .clamp(1, double.infinity);

    final recs = CropCatalog.crops.map((crop) {
      final cal = calibration?[crop.id];

      // Land suitability: barangay-specific where the map covers it, else the
      // crop's affinity for the farm's soil, else the catalog default.
      final soilScore =
          cal?.suitabilityForSoil(farm?.soilType) ?? crop.landSuitabilityScore;
      final suitability = area == null
          ? null
          : SuitabilityEngine.forCrop(
              barangay: area,
              cropId: crop.id,
              agronomy: agronomy,
              fallbackSoilScore: soilScore,
            );
      final suitabilityScore = suitability?.yieldIndex ?? soilScore;

      final suitsSeason = cal != null
          ? cal.suitsSeason(activeSeason)
          : crop.suitsSeason(activeSeason);
      final seasonScore = suitsSeason ? 1.0 : 0.35;

      final saturation = SaturationEngine.forCrop(
        cropId: crop.id,
        declarations: allDeclarations,
        demandOverride: demandOverrides?[crop.id],
      );
      // Lower saturation index → higher score. Clamp index to [0, 2].
      final satScore = (1 - (saturation.index.clamp(0, 2) / 2)).clamp(0.0, 1.0);

      final netPerHa = netPerHaByCrop[crop.id] ?? 0;
      final profitScore = (netPerHa / maxNet).clamp(0.0, 1.0);

      final score = suitabilityScore * wSuitability +
          seasonScore * wSeason +
          satScore * wSaturation +
          profitScore * wProfit;

      final attainableYield = cal?.meanYieldKgPerHa ?? crop.baselineYieldPerHa;

      return CropRecommendation(
        crop: crop,
        score: score,
        suitabilityScore: suitabilityScore,
        seasonScore: seasonScore,
        saturationScore: satScore,
        profitabilityScore: profitScore,
        saturation: saturation,
        suitability: suitability,
        projectedNetPerHa: netPerHa,
        expectedYieldPerHa: attainableYield * suitabilityScore,
        baselinePricePerKg:
            cal?.baselinePricePerKg ?? crop.baselinePricePerKg,
        rationale: _rationale(
          crop: crop,
          season: activeSeason,
          saturation: saturation,
          suitability: suitability,
          netPerHa: netPerHa,
          farm: farm,
        ),
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return recs;
  }

  /// Assess one specific planting plan — the panel shown live on the
  /// declaration form.
  static DeclarationRisk assess({
    required String cropId,
    required double areaHa,
    required String barangay,
    required DateTime plantingDate,
    required List<CropRecommendation> ranked,
    CropCalibration? calibration,
  }) {
    final rec = ranked.firstWhere(
      (r) => r.crop.id == cropId,
      orElse: () => ranked.first,
    );
    final reasons = <String>[];

    // Saturation is the dominant risk factor — it is what the whole system
    // exists to warn about.
    final satHigh = rec.saturation.level == SaturationLevel.high;
    final satModerate = rec.saturation.level == SaturationLevel.moderate;
    if (satHigh) {
      reasons.add(
          'Oversupply risk is high — ${rec.crop.name} supply is already '
          '${rec.saturation.index.toStringAsFixed(2)}× local demand.');
    } else if (satModerate) {
      reasons.add('Supply and demand for ${rec.crop.name} are near balance.');
    } else {
      reasons.add('There is room in the local market for ${rec.crop.name}.');
    }

    final band = rec.suitability?.band;
    if (band == SuitabilityBand.marginal) {
      reasons.add('$barangay is poorly suited to ${rec.crop.name} '
          '(${rec.suitability!.percent}% of attainable yield).');
    } else if (band == SuitabilityBand.moderate) {
      reasons.add('$barangay is only moderately suited to ${rec.crop.name} '
          '(${rec.suitability!.percent}% of attainable yield).');
    } else if (band != null) {
      reasons.add('$barangay suits ${rec.crop.name} well '
          '(${rec.suitability!.percent}% of attainable yield).');
    }

    final season = Season.forMonth(plantingDate.month);
    if (!rec.crop.suitsSeason(season)) {
      reasons.add('Planting in the ${season.label.toLowerCase()} is off-season '
          'for ${rec.crop.name} — expect a reduced yield.');
    }

    // Verdict: high saturation alone is enough; otherwise stack the softer
    // signals and require two to downgrade.
    final softFlags = [
      satModerate,
      band == SuitabilityBand.moderate,
      band == SuitabilityBand.marginal,
      !rec.crop.suitsSeason(season),
    ].where((f) => f).length;

    final verdict = satHigh || band == SuitabilityBand.marginal
        ? RiskVerdict.high
        : softFlags >= 2
            ? RiskVerdict.caution
            : softFlags == 1
                ? RiskVerdict.caution
                : RiskVerdict.low;

    final alternatives = ranked
        .where((r) =>
            r.crop.id != cropId &&
            r.saturation.level != SaturationLevel.high &&
            r.score > rec.score)
        .take(2)
        .toList();

    // Best/worst-case revenue from the crop's own price and yield distribution
    // (ScenarioEngine bands), so the farmer sees the spread they are exposed to
    // before committing rather than a single point estimate.
    final expectedYieldKg = rec.expectedYieldPerHa * areaHa;
    final scenarios = ScenarioEngine.build(
      expectedYieldKg: expectedYieldKg,
      projectedPricePerKg: rec.baselinePricePerKg,
      areaHa: areaHa,
      totalExpenses: 0,
      bestPriceUplift: calibration?.bestPriceUplift ?? 0.15,
      bestYieldUplift: calibration?.bestYieldUplift ?? 0.10,
      worstPriceDrop: calibration?.worstPriceDrop ?? 0.20,
      worstYieldDrop: calibration?.worstYieldDrop ?? 0.15,
    );
    var best = 0.0;
    var worst = 0.0;
    for (final s in scenarios) {
      if (s.kind == ScenarioKind.best) best = s.result.revenue;
      if (s.kind == ScenarioKind.worst) worst = s.result.revenue;
    }

    return DeclarationRisk(
      verdict: verdict,
      reasons: reasons,
      suitability: rec.suitability,
      saturation: rec.saturation,
      expectedYieldKg: expectedYieldKg,
      projectedPricePerKg: rec.baselinePricePerKg,
      bestCaseRevenue: best,
      worstCaseRevenue: worst,
      alternatives: alternatives,
    );
  }

  /// Build intercropping pairs from the top single-crop recommendations.
  static List<IntercropRecommendation> intercrops(
    List<CropRecommendation> ranked,
  ) {
    final byId = {for (final r in ranked) r.crop.id: r};
    final seen = <String>{};
    final pairs = <IntercropRecommendation>[];

    for (final r in ranked.take(5)) {
      for (final companionId in r.crop.companions) {
        final companionRec = byId[companionId];
        if (companionRec == null) continue;
        final key = ([r.crop.id, companionId]..sort()).join('+');
        if (seen.contains(key)) continue;
        seen.add(key);

        final combined = (r.score + companionRec.score) / 2;
        pairs.add(IntercropRecommendation(
          primary: r.crop,
          companion: companionRec.crop,
          combinedScore: combined,
          rationale:
              '${r.crop.name} + ${companionRec.crop.name} intercropping spreads '
              'market risk across two demand pools and optimizes land use; '
              'their growth cycles (${r.crop.growthDurationDays}d / '
              '${companionRec.crop.growthDurationDays}d) stagger harvest timing.',
        ));
      }
    }

    pairs.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));
    return pairs.take(4).toList();
  }

  static String _rationale({
    required CropProfile crop,
    required Season season,
    required SaturationResult saturation,
    required SuitabilityResult? suitability,
    required double netPerHa,
    required Farm? farm,
  }) {
    final parts = <String>[];
    parts.add(crop.suitsSeason(season)
        ? 'Well-suited to the current ${season.label.toLowerCase()}'
        : 'Off-season for ${crop.name} — yields may be reduced');
    if (suitability != null && suitability.isMapped) {
      parts.add('${suitability.band.label.toLowerCase()} in '
          '${suitability.barangay} (${suitability.percent}% of attainable yield)');
    }
    switch (saturation.level) {
      case SaturationLevel.low:
        parts.add('low local saturation (room in the market)');
        break;
      case SaturationLevel.moderate:
        parts.add('balanced supply vs demand');
        break;
      case SaturationLevel.high:
        parts.add('HIGH oversupply risk — consider an alternative');
        break;
    }
    if (farm != null && farm.previousCrops.contains(crop.id)) {
      parts.add('you have grown it before');
    }
    parts.add('projected net ≈ ₱${netPerHa.round()}/ha');
    return '${parts.join(', ')}.';
  }
}
