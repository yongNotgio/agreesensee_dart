import 'dart:convert';
import 'dart:io';

import 'package:agrisense/core/constants/app_constants.dart';
import 'package:agrisense/core/logic/crop_calendar_engine.dart';
import 'package:agrisense/core/logic/financial_engine.dart';
import 'package:agrisense/core/logic/recommendation_engine.dart';
import 'package:agrisense/core/logic/saturation_engine.dart';
import 'package:agrisense/core/logic/suitability_engine.dart';
import 'package:agrisense/data/agronomy_dataset.dart';
import 'package:agrisense/data/market_dataset.dart';
import 'package:agrisense/models/crop_declaration.dart';
import 'package:agrisense/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled JSON assets straight off disk, so these tests exercise the
/// same calibration the app ships with rather than hand-written fixtures.
List<dynamic> _asset(String name) =>
    jsonDecode(File('assets/data/$name.json').readAsStringSync()) as List;

MarketDataset _market() => MarketDataset.fromJson(
      agronomics: _asset('crop_agronomics'),
      costs: _asset('production_costs'),
      prices: _asset('market_prices_monthly'),
      demand: _asset('demand_baselines'),
    );

AgronomyDataset _agronomy() => AgronomyDataset.fromJson(
      varieties: _asset('crop_varieties'),
      stages: _asset('crop_growth_stages'),
      schedule: _asset('crop_activity_schedule'),
      suitability: _asset('barangay_suitability'),
    );

/// Harvest defaults to inside the saturation window, since the index only
/// counts supply arriving in the period it divides by.
CropDeclaration _declaration({
  required String id,
  required String cropId,
  required double yieldKg,
  DateTime? harvest,
  String barangay = 'Igpaho',
  DeclarationStatus status = DeclarationStatus.active,
}) =>
    CropDeclaration(
      id: id,
      farmerId: 'f1',
      farmId: 'farm1',
      cropId: cropId,
      variety: 'Galaxy',
      areaHa: 1,
      plantingDate: DateTime(2026, 1, 1),
      expectedHarvestDate:
          harvest ?? DateTime.now().add(const Duration(days: 30)),
      expectedYieldKg: yieldKg,
      barangay: barangay,
      status: status,
    );

void main() {
  group('Financial projection realism', () {
    // The adviser's sanity check: a realistic two-hectare planting should
    // project into the millions. If a future calibration change quietly breaks
    // that, this fails rather than the figure silently drifting.
    test('2 ha of tomato projects over 1M pesos of revenue', () {
      final cal = _market().forCrop('tomato')!;
      const areaHa = 2.0;
      final result = FinancialEngine.projection(
        expectedYieldKg: cal.meanYieldKgPerHa * areaHa,
        projectedPricePerKg: cal.baselinePricePerKg,
        areaHa: areaHa,
        expenses: const [],
        estimatedExpensesIfEmpty: cal.totalCostPerHa * areaHa,
      );

      expect(result.revenue, greaterThan(1000000));
      expect(result.netIncome, greaterThan(0));
      expect(result.isProfitable, isTrue);
    });

    test('ROI and break-even stay internally consistent', () {
      final result = FinancialEngine.projection(
        expectedYieldKg: 10000,
        projectedPricePerKg: 40,
        areaHa: 1,
        expenses: const [],
        estimatedExpensesIfEmpty: 100000,
      );

      expect(result.revenue, 400000);
      expect(result.netIncome, 300000);
      expect(result.roi, closeTo(3.0, 1e-9));
      expect(result.breakEvenYieldKg, closeTo(2500, 1e-9));
      expect(result.breakEvenPricePerKg, closeTo(10, 1e-9));
    });
  });

  group('Declaration status', () {
    // Rows written under the retired BAW → Technician → MAO approval chain must
    // still load after the collapse to active/harvested/cancelled.
    test('legacy approval values map onto the surviving states', () {
      for (final legacy in const [
        'draft',
        'pending',
        'baw_approved',
        'technician_verified',
        'approved',
        'correction_requested',
      ]) {
        expect(DeclarationStatus.fromWire(legacy), DeclarationStatus.active,
            reason: '$legacy should become active');
      }
      expect(DeclarationStatus.fromWire('rejected'),
          DeclarationStatus.cancelled);
      expect(DeclarationStatus.fromWire('harvested'),
          DeclarationStatus.harvested);
      expect(DeclarationStatus.fromWire(null), DeclarationStatus.active);
    });

    test('only active declarations count toward projected supply', () {
      final declarations = [
        _declaration(id: 'a', cropId: 'ampalaya', yieldKg: 12000),
        _declaration(
            id: 'b',
            cropId: 'ampalaya',
            yieldKg: 12000,
            status: DeclarationStatus.harvested),
        _declaration(
            id: 'c',
            cropId: 'ampalaya',
            yieldKg: 12000,
            status: DeclarationStatus.cancelled),
      ];
      final result = SaturationEngine.forCrop(
        cropId: 'ampalaya',
        declarations: declarations,
        demandOverride:
            const DemandFigure(tons: 100, source: DemandSource.baseline),
      );
      expect(result.expectedSupplyTons, 12.0);
      expect(result.contributingDeclarations, 1);
    });
  });

  group('Saturation', () {
    test('index bands split at 0.85 and 1.15', () {
      expect(SaturationEngine.levelForIndex(0.5), SaturationLevel.low);
      expect(SaturationEngine.levelForIndex(1.0), SaturationLevel.moderate);
      expect(SaturationEngine.levelForIndex(1.5), SaturationLevel.high);
    });

    test('demand provenance is carried through to the result', () {
      final result = SaturationEngine.forCrop(
        cropId: 'ampalaya',
        declarations: const [],
        demandOverride: const DemandFigure(
            tons: 40, source: DemandSource.cooperative, contributorCount: 3),
      );
      expect(result.demandSource, DemandSource.cooperative);
      expect(result.demand.provenance, contains('3 cooperative'));
    });

    test('monthly matrix buckets supply into its harvest month', () {
      final declarations = [
        _declaration(
            id: 'a',
            cropId: 'ampalaya',
            yieldKg: 5000,
            harvest: DateTime(2026, 2, 10)),
        _declaration(
            id: 'b',
            cropId: 'ampalaya',
            yieldKg: 7000,
            harvest: DateTime(2026, 2, 25)),
      ];
      final matrix = SaturationEngine.monthlyMatrix(
        declarations: declarations,
        monthlyDemand: (cropId, month) => 10,
        from: DateTime(2026, 1, 1),
        months: 3,
      );

      expect(matrix.at('ampalaya', DateTime(2026, 1, 1))!.supplyTons, 0);
      expect(matrix.at('ampalaya', DateTime(2026, 2, 1))!.supplyTons, 12.0);
      // 12 t against 10 t of demand is an oversupply.
      expect(matrix.at('ampalaya', DateTime(2026, 2, 1))!.level,
          SaturationLevel.high);
    });

    test('supply is grouped by barangay', () {
      final byBarangay = SaturationEngine.supplyByBarangay([
        _declaration(
            id: 'a', cropId: 'ampalaya', yieldKg: 3000, barangay: 'Igpaho'),
        _declaration(
            id: 'b', cropId: 'ampalaya', yieldKg: 2000, barangay: 'Igpaho'),
        _declaration(id: 'c', cropId: 'okra', yieldKg: 1000, barangay: 'Male'),
      ]);
      expect(byBarangay['Igpaho']!['ampalaya'], 5.0);
      expect(byBarangay['Male']!['okra'], 1.0);
    });
  });

  group('Land suitability', () {
    test('bands cut on the adviser\'s 50/70/80 thresholds', () {
      expect(SuitabilityBand.forIndex(0.49), SuitabilityBand.marginal);
      expect(SuitabilityBand.forIndex(0.50), SuitabilityBand.moderate);
      expect(SuitabilityBand.forIndex(0.69), SuitabilityBand.moderate);
      expect(SuitabilityBand.forIndex(0.70), SuitabilityBand.suitable);
      expect(SuitabilityBand.forIndex(0.79), SuitabilityBand.suitable);
      expect(SuitabilityBand.forIndex(0.80), SuitabilityBand.verySuitable);
    });

    test('every barangay in the catalog is mapped for every crop', () {
      final agronomy = _agronomy();
      expect(agronomy.barangays.length, AppConstants.barangays.length);

      for (final barangay in AppConstants.barangays) {
        for (final crop in CropCatalog.crops) {
          final result = SuitabilityEngine.forCrop(
            barangay: barangay,
            cropId: crop.id,
            agronomy: agronomy,
          );
          expect(result.isMapped, isTrue,
              reason: '${crop.id} in $barangay should be mapped');
          expect(result.yieldIndex, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('unmapped barangays fall back to the soil score and say so', () {
      final result = SuitabilityEngine.forCrop(
        barangay: 'Nowhere',
        cropId: 'ampalaya',
        agronomy: _agronomy(),
        fallbackSoilScore: 0.72,
      );
      expect(result.isMapped, isFalse);
      expect(result.yieldIndex, 0.72);
      expect(result.band, SuitabilityBand.suitable);
    });

    test('barangay ranking differs between barangays', () {
      final agronomy = _agronomy();
      final a = SuitabilityEngine.rankCropsForBarangay(
          barangay: AppConstants.barangays.first, agronomy: agronomy);
      final b = SuitabilityEngine.rankCropsForBarangay(
          barangay: AppConstants.barangays.last, agronomy: agronomy);
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      // The whole point of the map: location changes the numbers.
      expect(a.first.yieldIndex == b.first.yieldIndex, isFalse);
    });
  });

  group('Crop calendar', () {
    test('nursery crops schedule work before the transplant date', () {
      final agronomy = _agronomy();
      // Tomato is raised from seedlings; ampalaya is direct-seeded.
      expect(agronomy.usesSeedlings('tomato'), isTrue);
      expect(agronomy.usesSeedlings('ampalaya'), isFalse);

      final plantingDate = DateTime(2026, 6, 1);
      final sowing = CropCalendarEngine.sowingDateFor(
        cropId: 'tomato',
        plantingDate: plantingDate,
        agronomy: agronomy,
      );
      expect(sowing, isNotNull);
      expect(sowing!.isBefore(plantingDate), isTrue);
      expect(plantingDate.difference(sowing).inDays,
          agronomy.nurseryDaysFor('tomato'));

      expect(
        CropCalendarEngine.sowingDateFor(
          cropId: 'ampalaya',
          plantingDate: plantingDate,
          agronomy: agronomy,
        ),
        isNull,
      );
    });

    test('plan expands the protocol against the real planting date', () {
      final agronomy = _agronomy();
      final declaration = _declaration(
          id: 'd1', cropId: 'tomato', yieldKg: 20000);
      final plan = CropCalendarEngine.plan(
          declaration: declaration, agronomy: agronomy);

      expect(plan, isNotEmpty);
      // Ordered by date, and day 0 lands exactly on the planting date.
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].scheduledOn.isBefore(plan[i - 1].scheduledOn), isFalse);
      }
      final dayZero = plan.firstWhere((a) => a.daysAfterPlanting == 0);
      expect(dayZero.scheduledOn, DateTime(2026, 1, 1));

      // Land prep and nursery work precede planting.
      expect(plan.any((a) => a.daysAfterPlanting < 0), isTrue);
    });

    test('variety maturity shifts the harvest date', () {
      final agronomy = _agronomy();
      final varieties = agronomy.varietiesFor('tomato');
      expect(varieties.length, greaterThan(1));

      final early = varieties.reduce(
          (a, b) => a.maturityDays <= b.maturityDays ? a : b);
      final late = varieties.reduce(
          (a, b) => a.maturityDays >= b.maturityDays ? a : b);

      final plantingDate = DateTime(2026, 6, 1);
      DateTime harvestFor(String variety) =>
          CropCalendarEngine.harvestDateFor(
            cropId: 'tomato',
            plantingDate: plantingDate,
            agronomy: agronomy,
            variety: variety,
            fallbackGrowthDays: 75,
          );

      expect(harvestFor(early.name).isBefore(harvestFor(late.name)), isTrue);
    });

    test('rescheduling preserves work the farmer already acted on', () {
      final agronomy = _agronomy();
      final declaration =
          _declaration(id: 'd1', cropId: 'ampalaya', yieldKg: 12000);
      final original = CropCalendarEngine.plan(
          declaration: declaration, agronomy: agronomy);

      final done = original.first
          .copyWith(status: PlannedActivityStatus.done);
      final existing = [done, ...original.skip(1)];

      final moved = declaration.copyWith(
          plantingDate: DateTime(2026, 2, 1));
      final rescheduled = CropCalendarEngine.reschedule(
        declaration: moved,
        agronomy: agronomy,
        existing: existing,
      );

      // The completed operation survives untouched...
      final kept = rescheduled.firstWhere((a) => a.id == done.id);
      expect(kept.status, PlannedActivityStatus.done);
      expect(kept.scheduledOn, done.scheduledOn);
      // ...and is not duplicated by the freshly-dated plan.
      expect(
        rescheduled
            .where((a) => a.daysAfterPlanting == done.daysAfterPlanting)
            .length,
        1,
      );
    });
  });

  group('Recommendation', () {
    test('assessment flags a saturated crop as high risk', () {
      final agronomy = _agronomy();
      // Flood the market with ampalaya against a tiny demand figure.
      final declarations = [
        for (var i = 0; i < 30; i++)
          _declaration(id: 'd$i', cropId: 'ampalaya', yieldKg: 12000),
      ];
      final ranked = RecommendationEngine.recommend(
        farm: null,
        allDeclarations: declarations,
        barangay: 'Igpaho',
        calibration: _market().calibrations,
        agronomy: agronomy,
        demandOverrides: {
          'ampalaya':
              const DemandFigure(tons: 20, source: DemandSource.cooperative),
        },
      );

      final risk = RecommendationEngine.assess(
        cropId: 'ampalaya',
        areaHa: 1,
        barangay: 'Igpaho',
        plantingDate: DateTime(2026, 1, 15),
        ranked: ranked,
      );

      expect(risk.verdict, RiskVerdict.high);
      expect(risk.reasons, isNotEmpty);
      expect(risk.alternatives, isNotEmpty);
      // Alternatives must not themselves be oversupplied.
      for (final alt in risk.alternatives) {
        expect(alt.saturation.level, isNot(SaturationLevel.high));
      }
    });

    test('yield and price are derived, never zero, for a mapped barangay', () {
      final ranked = RecommendationEngine.recommend(
        farm: null,
        allDeclarations: const [],
        barangay: 'Igpaho',
        calibration: _market().calibrations,
        agronomy: _agronomy(),
      );
      final risk = RecommendationEngine.assess(
        cropId: 'tomato',
        areaHa: 2,
        barangay: 'Igpaho',
        plantingDate: DateTime(2026, 1, 15),
        ranked: ranked,
      );

      expect(risk.expectedYieldKg, greaterThan(0));
      expect(risk.projectedPricePerKg, greaterThan(0));
      expect(risk.projectedRevenue,
          closeTo(risk.expectedYieldKg * risk.projectedPricePerKg, 1e-6));
    });
  });

  group('Activity costing', () {
    test('every activity type maps to an expense category', () {
      for (final a in ActivityType.values) {
        expect(a.defaultExpenseCategory, isA<ExpenseCategory>());
      }
      expect(ActivityType.fertilizing.defaultExpenseCategory,
          ExpenseCategory.fertilizer);
      expect(ActivityType.pestControl.defaultExpenseCategory,
          ExpenseCategory.pesticide);
      expect(ActivityType.planting.defaultExpenseCategory,
          ExpenseCategory.seed);
    });
  });
}
