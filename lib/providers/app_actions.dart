import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/crop_calendar_engine.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/demand_signal.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
import '../models/planned_activity.dart';
import '../models/production_report.dart';
import 'core_providers.dart';
import 'data_providers.dart';

/// Centralized write surface for the UI. Each method performs the repository
/// mutation and then invalidates exactly the providers whose data changed —
/// derived analytics (saturation, harvest sync, recommendations) refresh
/// automatically because they `watch` [allDeclarationsProvider].
class AppActions {
  AppActions(this.ref);
  final Ref ref;

  // ── Farms ────────────────────────────────────────────────────────────────
  Future<Farm> saveFarm(Farm farm) async {
    final saved = await ref.read(farmRepositoryProvider).save(farm);
    ref.invalidate(farmsProvider);
    return saved;
  }

  // ── Declarations ───────────────────────────────────────────────────────────

  /// Save a declaration and (re)generate its crop calendar.
  ///
  /// The schedule is derived from the crop's agronomic protocol and the actual
  /// planting date, so the farmer gets a dated plan the moment they declare —
  /// rather than having to know when to fertilise, irrigate, and spray. On
  /// edit, operations the farmer has already acted on are preserved.
  ///
  /// The declaration itself always saves independently of the calendar: a
  /// failure generating the schedule must never make the crop disappear. But a
  /// failure here is not nothing either — it means the farmer opens the
  /// calendar tab to find it empty with no idea why. [calendarError] carries
  /// that failure back to the caller (non-null on failure) so the UI can say so,
  /// instead of the crop simply not being scheduled with zero explanation.
  Future<({CropDeclaration declaration, Object? calendarError})>
      saveDeclaration(
    CropDeclaration declaration, {
    bool regenerateCalendar = true,
  }) async {
    final saved =
        await ref.read(declarationRepositoryProvider).save(declaration);

    Object? calendarError;
    if (regenerateCalendar) {
      try {
        final agronomy = ref.read(agronomyDatasetProvider);
        final repo = ref.read(plannedActivityRepositoryProvider);
        final existing = await repo.forDeclaration(saved.id);
        final plan = existing.isEmpty
            ? CropCalendarEngine.plan(declaration: saved, agronomy: agronomy)
            : CropCalendarEngine.reschedule(
                declaration: saved,
                agronomy: agronomy,
                existing: existing,
              );
        // Replace the pending half of the plan; settled operations are re-saved
        // unchanged by `reschedule`, so a clean sweep is safe.
        await repo.removeForDeclaration(saved.id);
        await repo.saveAll(plan);
        ref.invalidate(plannedActivitiesProvider);
        ref.invalidate(plannedForDeclarationProvider(saved.id));
      } on Object catch (e) {
        // Not rethrown: the crop is recorded either way. Reported to the
        // caller instead so it can tell the farmer, rather than the schedule
        // just quietly never appearing.
        calendarError = e;
      }
    }

    ref.invalidate(declarationsProvider);
    ref.invalidate(allDeclarationsProvider);
    return (declaration: saved, calendarError: calendarError);
  }

  Future<void> deleteDeclaration(String id) async {
    await ref.read(plannedActivityRepositoryProvider).removeForDeclaration(id);
    await ref.read(declarationRepositoryProvider).remove(id);
    ref.invalidate(declarationsProvider);
    ref.invalidate(allDeclarationsProvider);
    ref.invalidate(plannedActivitiesProvider);
  }

  // ── Expenses ───────────────────────────────────────────────────────────────
  Future<void> saveExpense(Expense expense) async {
    await ref.read(expenseRepositoryProvider).save(expense);
    _refreshLedger(expense.declarationId);
  }

  Future<void> deleteExpense(Expense expense) async {
    await ref.read(expenseRepositoryProvider).remove(expense.id);
    // Unlink the originating activity so the logbook stops claiming a cost that
    // no longer exists in the ledger. Scoped to the owning farmer rather than
    // scanning every entry in the municipality.
    if (expense.logbookEntryId != null) {
      final logRepo = ref.read(logbookRepositoryProvider);
      final entries = await logRepo.forFarmer(expense.farmerId);
      for (final e in entries) {
        if (e.id == expense.logbookEntryId) {
          await logRepo.save(e.copyWith(clearCostLink: true));
          break;
        }
      }
      ref.invalidate(logbookProvider);
    }
    _refreshLedger(expense.declarationId);
  }

  // ── Logbook ───────────────────────────────────────────────────────────────

  /// Record a farm activity and, when it cost money, the expense it incurred —
  /// as one operation.
  ///
  /// Logging an activity and recording its cost used to be two separate forms,
  /// and a cost typed into the logbook never reached the P&L at all. A farmer
  /// either entered it twice or their ROI was quietly wrong. Now one entry
  /// produces both records, linked in both directions.
  ///
  /// The expense is written first so a failure leaves no logbook entry claiming
  /// a cost that was never recorded; if the entry write then fails, the expense
  /// is rolled back rather than orphaned in the ledger.
  Future<LogbookEntry> saveActivityWithCost(
    LogbookEntry entry, {
    Expense? expense,
  }) async {
    final logRepo = ref.read(logbookRepositoryProvider);

    if (expense == null) {
      final saved = await logRepo.save(entry);
      ref.invalidate(logbookProvider);
      return saved;
    }

    final expenseRepo = ref.read(expenseRepositoryProvider);
    final savedExpense = await expenseRepo.save(
      expense.copyWith(logbookEntryId: entry.id),
    );

    try {
      final saved = await logRepo.save(
        entry.copyWith(expenseId: savedExpense.id, cost: savedExpense.amount),
      );
      ref.invalidate(logbookProvider);
      _refreshLedger(savedExpense.declarationId);
      return saved;
    } on Object {
      // Roll back so the ledger never carries a cost with no activity behind it.
      await expenseRepo.remove(savedExpense.id);
      _refreshLedger(savedExpense.declarationId);
      rethrow;
    }
  }

  /// Delete a logbook entry together with the expense it created.
  Future<void> deleteActivityWithCost(LogbookEntry entry) async {
    if (entry.expenseId != null) {
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final all = await expenseRepo.forFarmer(entry.farmerId);
      for (final e in all) {
        if (e.id == entry.expenseId) {
          await expenseRepo.remove(e.id);
          _refreshLedger(e.declarationId);
          break;
        }
      }
    }
    await ref.read(logbookRepositoryProvider).remove(entry.id);
    ref.invalidate(logbookProvider);
  }

  // ── Crop calendar ─────────────────────────────────────────────────────────

  /// Mark a scheduled operation as done by logging what was actually performed,
  /// with the cost if one was incurred.
  Future<void> completePlannedActivity({
    required PlannedActivity planned,
    required LogbookEntry entry,
    Expense? expense,
  }) async {
    final saved = await saveActivityWithCost(
      entry.copyWith(plannedActivityId: planned.id),
      expense: expense,
    );
    await ref.read(plannedActivityRepositoryProvider).save(
          planned.copyWith(
            status: PlannedActivityStatus.done,
            logbookEntryId: saved.id,
            completedOn: entry.performedOn,
          ),
        );
    _refreshCalendar(planned.declarationId);
  }

  /// Dismiss a scheduled operation the farmer does not intend to perform.
  Future<void> skipPlannedActivity(PlannedActivity planned) async {
    await ref
        .read(plannedActivityRepositoryProvider)
        .save(planned.copyWith(status: PlannedActivityStatus.skipped));
    _refreshCalendar(planned.declarationId);
  }

  /// Restore a skipped operation to the schedule.
  Future<void> restorePlannedActivity(PlannedActivity planned) async {
    await ref
        .read(plannedActivityRepositoryProvider)
        .save(planned.copyWith(status: PlannedActivityStatus.pending));
    _refreshCalendar(planned.declarationId);
  }

  // ── Calamity reports ────────────────────────────────────────────────────────
  Future<void> saveCalamity(CalamityReport report) async {
    await ref.read(calamityRepositoryProvider).save(report);
    ref.invalidate(calamityProvider);
  }

  // ── Production reports (post-harvest P&L) ──────────────────────────────────
  Future<void> saveProductionReport(ProductionReport report) async {
    await ref.read(productionRepositoryProvider).save(report);
    ref.invalidate(productionReportsProvider);
    ref.invalidate(productionForDeclarationProvider(report.declarationId));
  }

  // ── Market channels (cooperative) ──────────────────────────────────────────
  Future<void> saveMarketChannel(MarketChannel channel) async {
    await ref.read(marketChannelRepositoryProvider).save(channel);
    ref.invalidate(marketChannelsProvider);
  }

  Future<void> deleteMarketChannel(String id) async {
    await ref.read(marketChannelRepositoryProvider).remove(id);
    ref.invalidate(marketChannelsProvider);
  }

  // ── Demand signals (cooperative) ──────────────────────────────────────────

  /// Record demand a cooperative commits to absorbing. This moves the
  /// saturation denominator off a hardcoded constant and onto a figure someone
  /// on the ground is accountable for.
  Future<void> saveDemandSignal(DemandSignal signal) async {
    await ref.read(demandSignalRepositoryProvider).save(signal);
    _refreshDemand();
  }

  Future<void> deleteDemandSignal(String id) async {
    await ref.read(demandSignalRepositoryProvider).remove(id);
    _refreshDemand();
  }

  // ── Invalidation helpers ──────────────────────────────────────────────────

  void _refreshLedger(String declarationId) {
    ref.invalidate(expensesForDeclarationProvider(declarationId));
    ref.invalidate(farmerExpensesProvider);
  }

  void _refreshCalendar(String declarationId) {
    ref.invalidate(plannedActivitiesProvider);
    ref.invalidate(plannedForDeclarationProvider(declarationId));
    ref.invalidate(dueActivitiesProvider);
    ref.invalidate(upcomingActivitiesProvider);
  }

  void _refreshDemand() {
    ref.invalidate(myDemandSignalsProvider);
    ref.invalidate(allDemandSignalsProvider);
    ref.invalidate(demandFiguresProvider);
    ref.invalidate(saturationProvider);
  }
}

final appActionsProvider = Provider<AppActions>((ref) => AppActions(ref));
