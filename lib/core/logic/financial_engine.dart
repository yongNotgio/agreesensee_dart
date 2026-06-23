import '../../models/expense.dart';
import '../../models/production_report.dart';

/// A computed financial forecast / P&L for a crop project (Objective 2).
class FinancialResult {
  const FinancialResult({
    required this.revenue,
    required this.totalExpenses,
    required this.expensesByCategory,
    required this.yieldKg,
    required this.pricePerKg,
    required this.areaHa,
    required this.isActual,
  });

  final double revenue;
  final double totalExpenses;
  final Map<String, double> expensesByCategory;
  final double yieldKg;
  final double pricePerKg;
  final double areaHa;

  /// True when derived from a [ProductionReport] (realized P&L) vs a pre-plant
  /// projection.
  final bool isActual;

  /// Net income = revenue − total expenses.
  double get netIncome => revenue - totalExpenses;

  /// Return on Investment = net income ÷ total expenses (as a fraction).
  double get roi => totalExpenses <= 0 ? 0 : netIncome / totalExpenses;

  /// Profit margin = net income ÷ revenue (as a fraction).
  double get profitMargin => revenue <= 0 ? 0 : netIncome / revenue;

  /// Break-even yield (kg): how many kg must sell, at [pricePerKg], to cover
  /// total expenses.
  double get breakEvenYieldKg =>
      pricePerKg <= 0 ? 0 : totalExpenses / pricePerKg;

  /// Break-even price (₱/kg): minimum price at the given yield to avoid a loss.
  double get breakEvenPricePerKg =>
      yieldKg <= 0 ? 0 : totalExpenses / yieldKg;

  /// How far current yield exceeds the break-even point (fraction of yield).
  double get marginOfSafety =>
      yieldKg <= 0 ? 0 : (yieldKg - breakEvenYieldKg) / yieldKg;

  double get costPerHa => areaHa <= 0 ? 0 : totalExpenses / areaHa;
  double get netIncomePerHa => areaHa <= 0 ? 0 : netIncome / areaHa;

  bool get isProfitable => netIncome > 0;
}

/// Pure financial computations (ROI, P&L, break-even).
class FinancialEngine {
  const FinancialEngine._();

  static Map<String, double> _byCategory(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category.label] = (map[e.category.label] ?? 0) + e.amount;
    }
    return map;
  }

  static double totalOf(List<Expense> expenses) =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);

  /// Pre-planting projection: projected revenue (expected yield × projected
  /// price) against logged-or-estimated expenses.
  static FinancialResult projection({
    required double expectedYieldKg,
    required double projectedPricePerKg,
    required double areaHa,
    required List<Expense> expenses,
    double? estimatedExpensesIfEmpty,
  }) {
    var total = totalOf(expenses);
    final byCat = _byCategory(expenses);
    if (expenses.isEmpty && estimatedExpensesIfEmpty != null) {
      total = estimatedExpensesIfEmpty;
      byCat['Estimated input cost'] = estimatedExpensesIfEmpty;
    }
    return FinancialResult(
      revenue: expectedYieldKg * projectedPricePerKg,
      totalExpenses: total,
      expensesByCategory: byCat,
      yieldKg: expectedYieldKg,
      pricePerKg: projectedPricePerKg,
      areaHa: areaHa,
      isActual: false,
    );
  }

  /// Realized post-harvest P&L from an actual production report + logged costs.
  static FinancialResult realized({
    required ProductionReport report,
    required double areaHa,
    required List<Expense> expenses,
  }) =>
      FinancialResult(
        revenue: report.actualRevenue,
        totalExpenses: totalOf(expenses),
        expensesByCategory: _byCategory(expenses),
        yieldKg: report.actualYieldKg,
        pricePerKg: report.actualPricePerKg,
        areaHa: areaHa,
        isActual: true,
      );
}
