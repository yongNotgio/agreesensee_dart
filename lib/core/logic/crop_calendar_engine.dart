import '../../data/agronomy_dataset.dart';
import '../../models/crop_declaration.dart';
import '../../models/planned_activity.dart';
import '../utils/id_gen.dart';

/// One stage of a declaration's growth cycle, resolved to real dates.
class CycleStage {
  const CycleStage({
    required this.stage,
    required this.label,
    required this.startsOn,
    required this.endsOn,
  });

  final String stage;
  final String label;
  final DateTime startsOn;
  final DateTime endsOn;

  bool get isNursery => stage == 'nursery';

  bool containsDate(DateTime d) =>
      !d.isBefore(_dayOf(startsOn)) && !d.isAfter(_dayOf(endsOn));

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Expands a crop's agronomic protocol into a dated plan for one declaration.
///
/// The logbook used to be purely reactive — it recorded what a farmer had
/// already done. The adviser's point was that the system already knows the crop
/// and the planting date, so it should say *when to fertilise, when to irrigate,
/// when to spray* rather than wait to be told. This engine is that: pure,
/// deterministic, offline expansion of `crop_activity_schedule` against a real
/// planting date.
class CropCalendarEngine {
  const CropCalendarEngine._();

  /// Build the full schedule of operations for [declaration].
  ///
  /// Day 0 is the transplant/direct-sowing date; nursery and land-preparation
  /// operations fall before it. Operations are clipped to the end of the
  /// harvest window.
  static List<PlannedActivity> plan({
    required CropDeclaration declaration,
    required AgronomyDataset agronomy,
    DateTime? createdAt,
  }) {
    final ops = agronomy.scheduleFor(declaration.cropId);
    if (ops.isEmpty) return const [];

    final day0 = _dayOf(declaration.plantingDate);
    final now = createdAt ?? DateTime.now();

    return ops.map((op) {
      return PlannedActivity(
        id: IdGen.uuid(),
        declarationId: declaration.id,
        farmerId: declaration.farmerId,
        activity: op.activity,
        title: op.title,
        scheduledOn: day0.add(Duration(days: op.daysAfterPlanting)),
        daysAfterPlanting: op.daysAfterPlanting,
        suggestedInput: op.input.isEmpty ? null : op.input,
        suggestedQtyPerHa: op.qtyPerHa == 0 ? null : op.qtyPerHa,
        unit: op.unit.isEmpty ? null : op.unit,
        createdAt: now,
      );
    }).toList()
      ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));
  }

  /// Resolve the declaration's growth stages to calendar dates — the visual
  /// "planting cycle halin sa seedlings" timeline.
  static List<CycleStage> stages({
    required CropDeclaration declaration,
    required AgronomyDataset agronomy,
  }) {
    final day0 = _dayOf(declaration.plantingDate);
    return agronomy
        .stagesFor(declaration.cropId)
        .map((s) => CycleStage(
              stage: s.stage,
              label: s.label,
              startsOn: day0.add(Duration(days: s.dayFrom)),
              endsOn: day0.add(Duration(days: s.dayTo)),
            ))
        .toList();
  }

  /// The stage a declaration is in right now, or null if the cycle has not
  /// started or is already finished.
  static CycleStage? currentStage({
    required CropDeclaration declaration,
    required AgronomyDataset agronomy,
    DateTime? now,
  }) {
    final today = _dayOf(now ?? DateTime.now());
    for (final s in stages(declaration: declaration, agronomy: agronomy)) {
      if (s.containsDate(today)) return s;
    }
    return null;
  }

  /// The date seed should go into the seedbed for a crop transplanted on
  /// [plantingDate]. Null for direct-seeded crops.
  static DateTime? sowingDateFor({
    required String cropId,
    required DateTime plantingDate,
    required AgronomyDataset agronomy,
  }) {
    final nursery = agronomy.nurseryDaysFor(cropId);
    if (nursery <= 0) return null;
    return _dayOf(plantingDate).subtract(Duration(days: nursery));
  }

  /// Expected harvest date = planting + the variety's maturity period, falling
  /// back to the crop's baseline growth duration when the variety is unknown.
  static DateTime harvestDateFor({
    required String cropId,
    required DateTime plantingDate,
    required AgronomyDataset agronomy,
    String? variety,
    required int fallbackGrowthDays,
  }) {
    final v = variety == null ? null : agronomy.variety(cropId, variety);
    final days = v?.maturityDays ?? fallbackGrowthDays;
    return _dayOf(plantingDate).add(Duration(days: days));
  }

  /// Operations due on or before [through], oldest first — the farmer's
  /// "what needs doing" list.
  static List<PlannedActivity> dueBy(
    List<PlannedActivity> activities,
    DateTime through,
  ) {
    final limit = _dayOf(through);
    final due = activities
        .where((a) => a.isPending && !_dayOf(a.scheduledOn).isAfter(limit))
        .toList()
      ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));
    return due;
  }

  /// Pending operations grouped by calendar day, for the month grid.
  static Map<DateTime, List<PlannedActivity>> groupByDay(
    List<PlannedActivity> activities,
  ) {
    final map = <DateTime, List<PlannedActivity>>{};
    for (final a in activities) {
      map.putIfAbsent(_dayOf(a.scheduledOn), () => []).add(a);
    }
    return map;
  }

  /// Regenerate the plan after a planting-date change, preserving what the
  /// farmer has already acted on.
  ///
  /// Completed and skipped operations are kept as-is — history is not rewritten
  /// — while still-pending ones are replaced by a freshly-dated plan.
  static List<PlannedActivity> reschedule({
    required CropDeclaration declaration,
    required AgronomyDataset agronomy,
    required List<PlannedActivity> existing,
  }) {
    final settled = existing.where((a) => !a.isPending).toList();
    final settledOffsets = settled.map((a) => a.daysAfterPlanting).toSet();
    final fresh = plan(declaration: declaration, agronomy: agronomy)
        .where((a) => !settledOffsets.contains(a.daysAfterPlanting))
        .toList();
    return [...settled, ...fresh]
      ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
