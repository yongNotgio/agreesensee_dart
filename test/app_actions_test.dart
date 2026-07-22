import 'dart:convert';
import 'dart:io';

import 'package:agrisense/core/config/app_config.dart';
import 'package:agrisense/core/logic/financial_engine.dart';
import 'package:agrisense/data/agronomy_dataset.dart';
import 'package:agrisense/models/crop_declaration.dart';
import 'package:agrisense/models/enums.dart';
import 'package:agrisense/models/expense.dart';
import 'package:agrisense/models/logbook_entry.dart';
import 'package:agrisense/providers/app_actions.dart';
import 'package:agrisense/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real repositories against an in-memory store in demo mode, so
/// these exercise the actual write path rather than a stand-in.
///
/// The headline behaviour under test is the activity/cost merge: a cost typed
/// into the logbook used to never reach the P&L, because the financial engine
/// only ever summed `Expense` rows. One save must now produce both records,
/// linked in both directions, and deleting either must not orphan the other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppActions actions;

  AgronomyDataset loadAgronomy() {
    List<dynamic> asset(String name) =>
        jsonDecode(File('assets/data/$name.json').readAsStringSync()) as List;
    return AgronomyDataset.fromJson(
      varieties: asset('crop_varieties'),
      stages: asset('crop_growth_stages'),
      schedule: asset('crop_activity_schedule'),
      suitability: asset('barangay_suitability'),
    );
  }

  setUp(() async {
    // Empty credentials force demo mode, so repositories treat the local cache
    // as the system of record.
    AppConfig.hydrateFromEnv(url: '', anonKey: '');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      agronomyDatasetProvider.overrideWithValue(loadAgronomy()),
    ]);
    actions = container.read(appActionsProvider);
  });

  tearDown(() => container.dispose());

  CropDeclaration declaration({String id = 'decl-1', String cropId = 'tomato'}) =>
      CropDeclaration(
        id: id,
        farmerId: 'farmer-1',
        farmId: 'farm-1',
        cropId: cropId,
        variety: 'Diamante Max',
        areaHa: 1,
        plantingDate: DateTime(2026, 6, 1),
        expectedHarvestDate: DateTime(2026, 8, 15),
        expectedYieldKg: 20000,
        barangay: 'Igpaho',
        status: DeclarationStatus.active,
      );

  LogbookEntry entry({String id = 'log-1', double? cost}) => LogbookEntry(
        id: id,
        farmerId: 'farmer-1',
        activity: ActivityType.fertilizing,
        title: 'Basal fertilizer application',
        performedOn: DateTime(2026, 6, 1),
        declarationId: 'decl-1',
        cost: cost,
      );

  Expense expense({String id = 'exp-1', double amount = 6400}) => Expense(
        id: id,
        declarationId: 'decl-1',
        farmerId: 'farmer-1',
        category: ExpenseCategory.fertilizer,
        description: 'Basal fertilizer application',
        amount: amount,
        incurredOn: DateTime(2026, 6, 1),
      );

  group('Activity + cost are one record', () {
    test('saving an activity with a cost writes both, linked both ways',
        () async {
      final saved = await actions.saveActivityWithCost(
        entry(cost: 6400),
        expense: expense(),
      );

      final logs = await container
          .read(logbookRepositoryProvider)
          .forFarmer('farmer-1');
      final expenses = await container
          .read(expenseRepositoryProvider)
          .forDeclaration('decl-1');

      expect(logs, hasLength(1));
      expect(expenses, hasLength(1));

      // Linked in both directions.
      expect(saved.expenseId, expenses.single.id);
      expect(logs.single.expenseId, expenses.single.id);
      expect(expenses.single.logbookEntryId, saved.id);
      expect(expenses.single.fromActivity, isTrue);

      // And the amount agrees, so the ledger cannot drift from the logbook.
      expect(logs.single.cost, 6400);
      expect(expenses.single.amount, 6400);
    });

    test('the cost actually reaches the P&L', () async {
      await actions.saveActivityWithCost(entry(cost: 6400), expense: expense());

      final expenses = await container
          .read(expenseRepositoryProvider)
          .forDeclaration('decl-1');

      // The regression that started all this: FinancialEngine only ever sums
      // Expense rows, so a logbook-only cost was invisible here.
      expect(FinancialEngine.totalOf(expenses), 6400);
    });

    test('an activity with no cost writes no expense', () async {
      await actions.saveActivityWithCost(entry());

      final logs = await container
          .read(logbookRepositoryProvider)
          .forFarmer('farmer-1');
      final expenses = await container
          .read(expenseRepositoryProvider)
          .forDeclaration('decl-1');

      expect(logs, hasLength(1));
      expect(logs.single.expenseId, isNull);
      expect(expenses, isEmpty);
    });

    test('deleting the activity removes its expense too', () async {
      final saved = await actions.saveActivityWithCost(
        entry(cost: 6400),
        expense: expense(),
      );

      await actions.deleteActivityWithCost(saved);

      expect(
        await container.read(logbookRepositoryProvider).forFarmer('farmer-1'),
        isEmpty,
      );
      expect(
        await container
            .read(expenseRepositoryProvider)
            .forDeclaration('decl-1'),
        isEmpty,
      );
    });

    test('deleting the expense unlinks the activity rather than orphaning it',
        () async {
      await actions.saveActivityWithCost(entry(cost: 6400), expense: expense());
      final stored = (await container
              .read(expenseRepositoryProvider)
              .forDeclaration('decl-1'))
          .single;

      await actions.deleteExpense(stored);

      final logs = await container
          .read(logbookRepositoryProvider)
          .forFarmer('farmer-1');

      // The activity survives — it still happened — but no longer claims a cost
      // that has left the ledger.
      expect(logs, hasLength(1));
      expect(logs.single.expenseId, isNull);
      expect(logs.single.cost, isNull);
      expect(logs.single.hasCost, isFalse);
    });
  });

  group('Declaring a crop builds its calendar', () {
    test('saving a declaration generates scheduled activities', () async {
      await actions.saveDeclaration(declaration());

      final planned = await container
          .read(plannedActivityRepositoryProvider)
          .forDeclaration('decl-1');

      expect(planned, isNotEmpty);
      expect(planned.every((a) => a.isPending), isTrue);
      // Tomato is nursery-raised, so seedbed work precedes the planting date.
      expect(planned.any((a) => a.daysAfterPlanting < 0), isTrue);
    });

    test('confirming a scheduled activity logs it and captures the cost',
        () async {
      await actions.saveDeclaration(declaration());
      final planned = await container
          .read(plannedActivityRepositoryProvider)
          .forDeclaration('decl-1');
      final target =
          planned.firstWhere((a) => a.activity == ActivityType.fertilizing);

      await actions.completePlannedActivity(
        planned: target,
        entry: entry(cost: 6400),
        expense: expense(),
      );

      final after = await container
          .read(plannedActivityRepositoryProvider)
          .forDeclaration('decl-1');
      final done = after.firstWhere((a) => a.id == target.id);

      expect(done.status, PlannedActivityStatus.done);
      expect(done.logbookEntryId, isNotNull);

      // And the cost still landed in the ledger.
      final expenses = await container
          .read(expenseRepositoryProvider)
          .forDeclaration('decl-1');
      expect(FinancialEngine.totalOf(expenses), 6400);
    });

    test('deleting a declaration clears its calendar', () async {
      await actions.saveDeclaration(declaration());
      expect(
        await container
            .read(plannedActivityRepositoryProvider)
            .forDeclaration('decl-1'),
        isNotEmpty,
      );

      await actions.deleteDeclaration('decl-1');

      expect(
        await container
            .read(plannedActivityRepositoryProvider)
            .forDeclaration('decl-1'),
        isEmpty,
      );
    });

    test('editing the planting date reschedules pending work only', () async {
      await actions.saveDeclaration(declaration());
      final planned = await container
          .read(plannedActivityRepositoryProvider)
          .forDeclaration('decl-1');
      final target =
          planned.firstWhere((a) => a.activity == ActivityType.fertilizing);

      await actions.skipPlannedActivity(target);

      final moved = declaration().copyWith(
        plantingDate: DateTime(2026, 7, 1),
      );
      await actions.saveDeclaration(moved);

      final after = await container
          .read(plannedActivityRepositoryProvider)
          .forDeclaration('decl-1');

      // The settled item keeps its status and original date; history is not
      // rewritten under the farmer.
      final settled = after.firstWhere((a) => a.id == target.id);
      expect(settled.status, PlannedActivityStatus.skipped);
      expect(settled.scheduledOn, target.scheduledOn);

      // Everything still pending moved with the new planting date.
      final pending = after.where((a) => a.isPending).toList();
      expect(pending, isNotEmpty);
      expect(
        pending.any((a) => a.scheduledOn.isAfter(DateTime(2026, 6, 20))),
        isTrue,
      );
    });
  });
}
