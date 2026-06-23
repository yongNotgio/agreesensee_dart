import 'financial_engine.dart';

/// One of the three risk scenarios (Phase 8 — Risk & Scenario Analysis).
enum ScenarioKind {
  best('Best Case'),
  expected('Expected'),
  worst('Worst Case');

  const ScenarioKind(this.label);
  final String label;
}

/// A modeled outcome under a price/yield shock.
class Scenario {
  const Scenario({
    required this.kind,
    required this.priceFactor,
    required this.yieldFactor,
    required this.result,
  });

  final ScenarioKind kind;
  final double priceFactor;
  final double yieldFactor;
  final FinancialResult result;

  double get netIncome => result.netIncome;
  double get roi => result.roi;
}

/// Builds best/expected/worst scenarios by shocking price and yield around a
/// baseline projection.
class ScenarioEngine {
  const ScenarioEngine._();

  /// Default ±sensitivities. Best case: +15% price, +10% yield. Worst case:
  /// −20% price, −15% yield. These mirror typical farmgate volatility.
  static List<Scenario> build({
    required double expectedYieldKg,
    required double projectedPricePerKg,
    required double areaHa,
    required double totalExpenses,
    double bestPriceUplift = 0.15,
    double bestYieldUplift = 0.10,
    double worstPriceDrop = 0.20,
    double worstYieldDrop = 0.15,
  }) {
    Scenario make(ScenarioKind kind, double priceF, double yieldF) {
      final result = FinancialEngine.projection(
        expectedYieldKg: expectedYieldKg * yieldF,
        projectedPricePerKg: projectedPricePerKg * priceF,
        areaHa: areaHa,
        expenses: const [],
        estimatedExpensesIfEmpty: totalExpenses,
      );
      return Scenario(
        kind: kind,
        priceFactor: priceF,
        yieldFactor: yieldF,
        result: result,
      );
    }

    return [
      make(ScenarioKind.best, 1 + bestPriceUplift, 1 + bestYieldUplift),
      make(ScenarioKind.expected, 1.0, 1.0),
      make(ScenarioKind.worst, 1 - worstPriceDrop, 1 - worstYieldDrop),
    ];
  }
}
