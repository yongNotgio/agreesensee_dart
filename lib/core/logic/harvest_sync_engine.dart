import '../../models/crop_declaration.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';

/// Aggregated harvest volume for one crop within one ISO week.
class HarvestPeak {
  const HarvestPeak({
    required this.cropId,
    required this.weekLabel,
    required this.weekStart,
    required this.farmerCount,
    required this.volumeTons,
    required this.isCongested,
  });

  final String cropId;
  final String weekLabel;
  final DateTime weekStart;
  final int farmerCount;
  final double volumeTons;

  /// True when the number of farmers harvesting this crop this week meets or
  /// exceeds the congestion threshold (risk of simultaneous market dumping).
  final bool isCongested;

  String get cropName => CropCatalog.nameFor(cropId);
}

/// A staggering recommendation to resolve a congested harvest window
/// (Phase 9 — Harvest Synchronization).
class SyncSuggestion {
  const SyncSuggestion({
    required this.peak,
    required this.suggestedShiftDays,
    required this.alternativeCropIds,
    required this.message,
  });

  final HarvestPeak peak;

  /// Days to delay/advance planting to move out of the congested window.
  final int suggestedShiftDays;
  final List<String> alternativeCropIds;
  final String message;
}

/// Harvest synchronization logic: detect congested harvest peaks and propose
/// staggering / intercropping / alternative-crop mitigations.
///
/// Implements Objective 1's "automated harvest timelines to mitigate the risk
/// of local oversupply" and feeds the cooperative supply-chain dashboard
/// (Objective 3).
class HarvestSyncEngine {
  const HarvestSyncEngine._();

  /// Monday of the ISO week containing [date].
  static DateTime weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Bucket active declarations by crop × harvest week and flag congestion.
  static List<HarvestPeak> peaks(
    List<CropDeclaration> declarations, {
    int threshold = AppConstants.harvestCongestionThreshold,
  }) {
    final buckets = <String, List<CropDeclaration>>{};
    for (final d in declarations) {
      if (!d.status.isActive) continue;
      final start = weekStart(d.expectedHarvestDate);
      final key = '${d.cropId}|${start.toIso8601String()}';
      buckets.putIfAbsent(key, () => []).add(d);
    }

    final result = <HarvestPeak>[];
    buckets.forEach((key, group) {
      final cropId = key.split('|').first;
      final start = group.first.expectedHarvestDate;
      final ws = weekStart(start);
      final farmers = group.map((d) => d.farmerId).toSet().length;
      final volume =
          group.fold<double>(0, (sum, d) => sum + d.expectedYieldTons);
      result.add(HarvestPeak(
        cropId: cropId,
        weekLabel: Fmt.isoWeekLabel(ws),
        weekStart: ws,
        farmerCount: farmers,
        volumeTons: volume,
        isCongested: farmers >= threshold,
      ));
    });

    result.sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return result;
  }

  /// Produce staggering suggestions for the congested peaks only.
  static List<SyncSuggestion> suggestions(
    List<CropDeclaration> declarations, {
    int threshold = AppConstants.harvestCongestionThreshold,
  }) {
    final congested =
        peaks(declarations, threshold: threshold).where((p) => p.isCongested);
    return congested.map((peak) {
      final crop = CropCatalog.byIdOrFirst(peak.cropId);
      // Shift by roughly a fifth of the growth cycle (min 7 days) to spread the
      // window without missing the season.
      final shift = (crop.growthDurationDays * 0.2).round().clamp(7, 30);
      return SyncSuggestion(
        peak: peak,
        suggestedShiftDays: shift,
        alternativeCropIds: crop.companions,
        message:
            '${peak.farmerCount} farmers are set to harvest ${peak.cropName} '
            'during ${peak.weekLabel} (${Fmt.tons(peak.volumeTons)}). '
            'Stagger planting by ~$shift days, intercrop, or shift to '
            '${crop.companions.map(CropCatalog.nameFor).join(' / ')} to avoid '
            'simultaneous market dumping.',
      );
    }).toList();
  }

  /// Weekly supply projection for one crop over the next [weeks] ISO weeks —
  /// the time series the cooperative dashboard charts (Objective 3).
  static List<HarvestPeak> projectionForCrop(
    List<CropDeclaration> declarations,
    String cropId, {
    int weeks = 12,
  }) {
    final all = peaks(declarations).where((p) => p.cropId == cropId).toList();
    final today = weekStart(DateTime.now());
    final series = <HarvestPeak>[];
    for (var i = 0; i < weeks; i++) {
      final ws = today.add(Duration(days: i * 7));
      final match = all.where((p) => _sameWeek(p.weekStart, ws)).toList();
      if (match.isNotEmpty) {
        series.add(match.first);
      } else {
        series.add(HarvestPeak(
          cropId: cropId,
          weekLabel: Fmt.isoWeekLabel(ws),
          weekStart: ws,
          farmerCount: 0,
          volumeTons: 0,
          isCongested: false,
        ));
      }
    }
    return series;
  }

  static bool _sameWeek(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
