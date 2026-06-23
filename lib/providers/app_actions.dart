import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
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
  Future<CropDeclaration> saveDeclaration(CropDeclaration declaration) async {
    final saved =
        await ref.read(declarationRepositoryProvider).save(declaration);
    ref.invalidate(declarationsProvider);
    ref.invalidate(allDeclarationsProvider);
    return saved;
  }

  Future<void> deleteDeclaration(String id) async {
    await ref.read(declarationRepositoryProvider).remove(id);
    ref.invalidate(declarationsProvider);
    ref.invalidate(allDeclarationsProvider);
  }

  // ── Expenses ───────────────────────────────────────────────────────────────
  Future<void> saveExpense(Expense expense) async {
    await ref.read(expenseRepositoryProvider).save(expense);
    ref.invalidate(expensesForDeclarationProvider(expense.declarationId));
    ref.invalidate(farmerExpensesProvider);
  }

  Future<void> deleteExpense(Expense expense) async {
    await ref.read(expenseRepositoryProvider).remove(expense.id);
    ref.invalidate(expensesForDeclarationProvider(expense.declarationId));
    ref.invalidate(farmerExpensesProvider);
  }

  // ── Logbook ───────────────────────────────────────────────────────────────
  Future<void> saveLogEntry(LogbookEntry entry) async {
    await ref.read(logbookRepositoryProvider).save(entry);
    ref.invalidate(logbookProvider);
  }

  Future<void> deleteLogEntry(String id) async {
    await ref.read(logbookRepositoryProvider).remove(id);
    ref.invalidate(logbookProvider);
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
}

final appActionsProvider = Provider<AppActions>((ref) => AppActions(ref));
