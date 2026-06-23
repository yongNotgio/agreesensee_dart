import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../logic/harvest_sync_engine.dart';
import '../logic/scenario_engine.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Donut chart of expenses by category for the P&L breakdown (Objective 2).
class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.byCategory});

  final Map<String, double> byCategory;

  static const _palette = [
    Color(0xFF2E7D32),
    Color(0xFF00796B),
    Color(0xFFF9A825),
    Color(0xFF1565C0),
    Color(0xFF6A4C93),
    Color(0xFFEF6C00),
    Color(0xFFC2185B),
    Color(0xFF455A64),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No expenses logged yet')),
      );
    }
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 36,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _palette[i % _palette.length],
                    title: '${(entries[i].value / total * 100).round()}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entries[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text(Fmt.pesoCompact(entries[i].value),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grouped bar chart of net income across best / expected / worst scenarios
/// (Objective 2 — Risk & Scenario Analysis).
class ScenarioBarChart extends StatelessWidget {
  const ScenarioBarChart({super.key, required this.scenarios});

  final List<Scenario> scenarios;

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) return const SizedBox.shrink();
    final maxV = scenarios
        .map((s) => s.netIncome.abs())
        .fold<double>(1, (m, v) => v > m ? v : m);

    Color colorFor(ScenarioKind k) => switch (k) {
          ScenarioKind.best => AppColors.success,
          ScenarioKind.expected => AppColors.info,
          ScenarioKind.worst => AppColors.danger,
        };

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxV * 1.2,
          minY: scenarios.any((s) => s.netIncome < 0) ? -maxV * 1.2 : 0,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  Fmt.pesoCompact(v),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= scenarios.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(scenarios[i].kind.label,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < scenarios.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: scenarios[i].netIncome,
                  color: colorFor(scenarios[i].kind),
                  width: 28,
                  borderRadius: BorderRadius.circular(6),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Line chart of a crop's weekly supply projection in tons (Objective 3).
class SupplyLineChart extends StatelessWidget {
  const SupplyLineChart({
    super.key,
    required this.series,
    this.demandTons,
  });

  final List<HarvestPeak> series;
  final double? demandTons;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i].volumeTons),
    ];
    final maxV = series
        .map((p) => p.volumeTons)
        .fold<double>(1, (m, v) => v > m ? v : m);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxV * 1.25,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, _) =>
                    Text('${v.toStringAsFixed(0)}t',
                        style: const TextStyle(fontSize: 9)),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (series.length / 5).ceilToDouble().clamp(1, 99),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox();
                  final ws = series[i].weekStart;
                  final mm = ws.month.toString().padLeft(2, '0');
                  final dd = ws.day.toString().padLeft(2, '0');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$mm/$dd',
                        style: const TextStyle(fontSize: 8)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: demandTons == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: demandTons!,
                    color: AppColors.riskHigh,
                    strokeWidth: 2,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.riskHigh),
                      labelResolver: (_) => 'Demand',
                    ),
                  ),
                ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: AppColors.primary,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) {
                  final congested =
                      series[spot.x.toInt()].isCongested;
                  return FlDotCirclePainter(
                    radius: congested ? 5 : 3,
                    color: congested ? AppColors.riskHigh : AppColors.primary,
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
