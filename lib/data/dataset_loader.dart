import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'agronomy_dataset.dart';
import 'market_dataset.dart';

/// The bundled reference data, loaded once at boot.
class ReferenceData {
  const ReferenceData({required this.market, required this.agronomy});
  final MarketDataset market;
  final AgronomyDataset agronomy;
}

/// Loads and calibrates the bundled datasets from `assets/data/`.
///
/// Each half degrades independently: if the agronomy assets are missing the app
/// still prices and forecasts, and if the market assets are missing it still
/// schedules and advises. Either way it boots.
class DatasetLoader {
  const DatasetLoader._();

  static Future<ReferenceData> load() async {
    return ReferenceData(
      market: await loadMarket(),
      agronomy: await loadAgronomy(),
    );
  }

  static Future<MarketDataset> loadMarket() async {
    try {
      final results = await Future.wait([
        _readJsonArray('assets/data/crop_agronomics.json'),
        _readJsonArray('assets/data/production_costs.json'),
        _readJsonArray('assets/data/market_prices_monthly.json'),
        _readJsonArray('assets/data/demand_baselines.json'),
      ]);
      final dataset = MarketDataset.fromJson(
        agronomics: results[0],
        costs: results[1],
        prices: results[2],
        demand: results[3],
      );
      return dataset.isEmpty ? MarketDataset.fallback() : dataset;
    } on Object {
      return MarketDataset.fallback();
    }
  }

  static Future<AgronomyDataset> loadAgronomy() async {
    try {
      final results = await Future.wait([
        _readJsonArray('assets/data/crop_varieties.json'),
        _readJsonArray('assets/data/crop_growth_stages.json'),
        _readJsonArray('assets/data/crop_activity_schedule.json'),
        _readJsonArray('assets/data/barangay_suitability.json'),
      ]);
      final dataset = AgronomyDataset.fromJson(
        varieties: results[0],
        stages: results[1],
        schedule: results[2],
        suitability: results[3],
      );
      return dataset.isEmpty ? AgronomyDataset.empty : dataset;
    } on Object {
      return AgronomyDataset.empty;
    }
  }

  static Future<List<dynamic>> _readJsonArray(String path) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  }
}
