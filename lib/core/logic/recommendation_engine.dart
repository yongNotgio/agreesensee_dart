import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/farm.dart';
import '../constants/app_constants.dart';
import 'saturation_engine.dart';

/// A ranked crop recommendation with an explainable score breakdown
/// (Objective 1 — single-crop strategy).
class CropRecommendation {
  const CropRecommendation({
    required this.crop,
    required this.score,
    required this.suitabilityScore,
    required this.seasonScore,
    required this.saturationScore,
    required this.profitabilityScore,
    required this.saturation,
    required this.projectedNetPerHa,
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
  final double projectedNetPerHa;
  final String rationale;

  int get scorePercent => (score * 100).round();
  bool get isHighlyRecommended => score >= 0.7;
}

/// An intercropping (mix-and-match) pairing recommendation (Objective 1).
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

/// Weighted, explainable crop recommendation engine.
///
/// Blends four normalized signals — land suitability, seasonal fit, market
/// saturation (inverse), and projected profitability — into a single score,
/// then surfaces both single-crop and intercropping strategies. Pure & local,
/// matching the manuscript's "no heavy external ML" delimitation.
class RecommendationEngine {
  const RecommendationEngine._();

  // Signal weights (sum = 1.0).
  static const double wSuitability = 0.25;
  static const double wSeason = 0.20;
  static const double wSaturation = 0.30; // oversupply avoidance is paramount
  static const double wProfit = 0.25;

  /// Assumed input cost per hectare used to normalize profitability when the
  /// farmer has no logged expenses yet (₱ per ha).
  static const double assumedCostPerHa = 45000;

  static List<CropRecommendation> recommend({
    required Farm? farm,
    required List<CropDeclaration> allDeclarations,
    Season? season,
    Map<String, double>? demandOverrides,
  }) {
    final activeSeason = season ?? Season.forMonth(DateTime.now().month);

    // Normalize profitability across the catalog so the score is comparable.
    final netPerHaByCrop = <String, double>{};
    for (final c in CropCatalog.crops) {
      final revenue = c.baselineYieldPerHa * c.baselinePricePerKg;
      netPerHaByCrop[c.id] = revenue - assumedCostPerHa;
    }
    final maxNet = netPerHaByCrop.values
        .fold<double>(1, (m, v) => v > m ? v : m)
        .clamp(1, double.infinity);

    final recs = CropCatalog.crops.map((crop) {
      final suitability = crop.landSuitabilityScore;
      final seasonScore = crop.suitsSeason(activeSeason) ? 1.0 : 0.35;

      final saturation = SaturationEngine.forCrop(
        cropId: crop.id,
        declarations: allDeclarations,
        demandOverride: demandOverrides?[crop.id],
      );
      // Lower saturation index → higher score. Clamp index to [0, 2].
      final satScore = (1 - (saturation.index.clamp(0, 2) / 2)).clamp(0.0, 1.0);

      final netPerHa = netPerHaByCrop[crop.id] ?? 0;
      final profitScore = (netPerHa / maxNet).clamp(0.0, 1.0);

      final score = suitability * wSuitability +
          seasonScore * wSeason +
          satScore * wSaturation +
          profitScore * wProfit;

      return CropRecommendation(
        crop: crop,
        score: score,
        suitabilityScore: suitability,
        seasonScore: seasonScore,
        saturationScore: satScore,
        profitabilityScore: profitScore,
        saturation: saturation,
        projectedNetPerHa: netPerHa,
        rationale: _rationale(
          crop: crop,
          season: activeSeason,
          saturation: saturation,
          netPerHa: netPerHa,
          farm: farm,
        ),
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return recs;
  }

  /// Build intercropping pairs from the top single-crop recommendations using
  /// the catalog's companion relationships.
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
    required double netPerHa,
    required Farm? farm,
  }) {
    final parts = <String>[];
    parts.add(crop.suitsSeason(season)
        ? 'Well-suited to the current ${season.label.toLowerCase()}'
        : 'Off-season for ${crop.name} — yields may be reduced');
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
      parts.add('you have grown it before on ${farm.name}');
    }
    parts.add('projected net ≈ ₱${netPerHa.round()}/ha');
    return '${parts.join(', ')}.';
  }
}
