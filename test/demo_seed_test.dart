import 'dart:convert';
import 'dart:io';

import 'package:agrisense/core/cache/local_cache.dart';
import 'package:agrisense/core/config/app_config.dart';
import 'package:agrisense/core/logic/saturation_engine.dart';
import 'package:agrisense/data/market_dataset.dart';
import 'package:agrisense/models/crop_declaration.dart';
import 'package:agrisense/models/enums.dart';
import 'package:agrisense/models/production_report.dart';
import 'package:agrisense/repositories/demo_seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the *plausibility* of the seeded municipal dataset.
///
/// The seed used to put 42 of 50 farmers on one crop at 1.0–1.6 ha each,
/// harvesting the same week — 655 t of ampalaya against a municipality that
/// absorbs ~125 t a quarter. Every crop read as catastrophically oversupplied,
/// which is not a demo, it is noise. These assertions keep the numbers in a
/// range a farmer or a panel would recognise as real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<CropDeclaration> declarations;
  late List<ProductionReport> reports;
  late MarketDataset market;

  setUpAll(() async {
    AppConfig.hydrateFromEnv(url: '', anonKey: '');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = LocalCache(prefs);
    await DemoSeed.ensureSeeded(cache);

    declarations = cache
        .readList('crop_declarations')
        .map(CropDeclaration.fromMap)
        .toList();
    reports = cache
        .readList('production_reports')
        .map(ProductionReport.fromMap)
        .toList();

    List<dynamic> asset(String name) =>
        jsonDecode(File('assets/data/$name.json').readAsStringSync()) as List;
    market = MarketDataset.fromJson(
      agronomics: asset('crop_agronomics'),
      costs: asset('production_costs'),
      prices: asset('market_prices_monthly'),
      demand: asset('demand_baselines'),
    );
  });

  /// Saturation over the standard window, using the seasonal baseline demand.
  List<SaturationResult> saturation() {
    final window = SaturationWindow.next(SaturationEngine.defaultWindowDays);
    return SaturationEngine.forAllCrops(
      declarations,
      window: window,
      demandOverrides: {
        for (final entry in market.calibrations.entries)
          entry.key: DemandFigure(
            tons: entry.value.demandBetween(window.start, window.end),
            source: DemandSource.baseline,
          ),
      },
    );
  }

  test('the municipality is a plausible size', () {
    final farmers = declarations.map((d) => d.farmerId).toSet();
    final area = declarations
        .where((d) => d.status.isActive)
        .fold<double>(0, (s, d) => s + d.areaHa);

    expect(farmers.length, inInclusiveRange(40, 60),
        reason: 'an association of roughly 50 members');
    expect(area, inInclusiveRange(20, 45),
        reason: 'roughly 30 ha planted across the association');
  });

  test('plot sizes are smallholder-scale', () {
    for (final d in declarations) {
      expect(d.areaHa, inInclusiveRange(0.2, 1.5),
          reason: '${d.cropId} plot of ${d.areaHa} ha is not a smallholder plot');
    }
    final mean = declarations.fold<double>(0, (s, d) => s + d.areaHa) /
        declarations.length;
    expect(mean, lessThan(0.9), reason: 'mean plot should stay under a hectare');
  });

  test('no crop is absurdly oversupplied', () {
    for (final r in saturation()) {
      expect(r.index, lessThan(3.0),
          reason: '${r.cropId} at ${r.index.toStringAsFixed(2)}x demand is not '
              'a believable figure — check supply and demand cover the same '
              'window');
    }
  });

  test('the oversupply scenario is demonstrable without swamping everything',
      () {
    final results = saturation();
    final high =
        results.where((r) => r.level == SaturationLevel.high).toList();
    final low = results.where((r) => r.level == SaturationLevel.low).toList();

    // Exactly one crop should be the teaching example.
    expect(high, hasLength(1),
        reason: 'one crop should read High, not none and not all of them');
    expect(high.single.cropId, 'ampalaya');

    // And most crops should still have headroom.
    expect(low.length, greaterThanOrEqualTo(4),
        reason: 'most crops should have room in the market');
  });

  test('supply is spread across crops, not piled on one', () {
    final byCrop = <String, int>{};
    for (final d in declarations.where((d) => d.status.isActive)) {
      byCrop[d.cropId] = (byCrop[d.cropId] ?? 0) + 1;
    }
    expect(byCrop.keys.length, greaterThanOrEqualTo(6),
        reason: 'the association should grow a real mix of crops');

    final onBiggest = byCrop.values.reduce((a, b) => a > b ? a : b);
    final total = byCrop.values.reduce((a, b) => a + b);
    expect(onBiggest / total, lessThan(0.5),
        reason: 'no single crop should account for half the declarations');
  });

  test('a finished project exists, with its harvest recorded', () {
    // Without a harvested declaration and a matching production report, the
    // Harvest tab, the realised P&L, and the sold-to capture are all dead
    // screens — nothing to render and nothing to demonstrate.
    final harvested = declarations
        .where((d) => d.status == DeclarationStatus.harvested)
        .toList();
    expect(harvested, isNotEmpty,
        reason: 'at least one completed project is needed');

    expect(reports, isNotEmpty, reason: 'the harvest must be recorded');

    for (final r in reports) {
      expect(
        harvested.any((d) => d.id == r.declarationId),
        isTrue,
        reason: 'production report ${r.id} must point at a harvested crop',
      );
      expect(r.actualYieldKg, greaterThan(0));
      expect(r.actualPricePerKg, greaterThan(0));
    }
  });

  test('the harvest records where the produce went', () {
    // The supply-chain view can only show what was captured. A report with no
    // channel answers none of "diin nagkadto ang supply?".
    for (final r in reports) {
      expect(r.buyerName, isNotNull,
          reason: 'a named buyer is what makes the chain traceable');
      expect(r.soldToChannel, isNot(SalesChannel.other),
          reason: 'the channel should be specific, not a catch-all');
    }
  });

  test('harvests are spread, with a real cluster rather than one day', () {
    final ampalaya = declarations
        .where((d) => d.cropId == 'ampalaya' && d.status.isActive)
        .map((d) => d.expectedHarvestDate)
        .toList()
      ..sort();

    final spanDays = ampalaya.last.difference(ampalaya.first).inDays;
    expect(spanDays, greaterThan(14),
        reason: 'a glut is a crowded few weeks, not every farmer picking the '
            'same morning');
    expect(spanDays, lessThan(120),
        reason: 'but it should still be a recognisable cluster');
  });
}
