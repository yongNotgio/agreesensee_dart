import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'market_dataset.dart';

/// Loads and calibrates the bundled market datasets from `assets/data/`.
///
/// If any asset is missing or malformed (e.g. on a platform where the bundle
/// differs), it transparently falls back to [MarketDataset.fallback] so the
/// engines always have parameters and the app never fails to boot.
class DatasetLoader {
  const DatasetLoader._();

  static Future<MarketDataset> load() async {
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

  static Future<List<dynamic>> _readJsonArray(String path) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  }
}
