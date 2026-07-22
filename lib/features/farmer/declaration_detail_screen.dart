import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/crop_calendar_engine.dart';
import '../../core/logic/financial_engine.dart';
import '../../core/logic/saturation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/market_dataset.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/production_report.dart';
import '../../providers/app_actions.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import 'declaration_form_screen.dart';
import 'expense_sheet.dart';
import 'production_report_sheet.dart';

/// Full detail of a crop declaration with three tabs:
///   • Overview   — declaration data, growth-cycle progress, market saturation
///   • Financials — the expense ledger and realised ROI
///   • Harvest    — post-harvest production report and realized P&L
///
/// The Financials tab no longer opens with a speculative pre-planting forecast.
/// Projecting profit from numbers a farmer had to guess dressed up guesswork as
/// analysis; the ROI shown here is computed from costs actually logged and, once
/// harvested, revenue actually received. The forward-looking figures now live
/// where they are actionable — in the risk panel *before* the crop is declared.
class DeclarationDetailScreen extends ConsumerWidget {
  const DeclarationDetailScreen({super.key, required this.declarationId});
  final String declarationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final declarations = ref.watch(declarationsProvider);
    return AsyncValueView(
      value: declarations,
      onRetry: () => ref.invalidate(declarationsProvider),
      data: (list) {
        CropDeclaration? declaration;
        for (final d in list) {
          if (d.id == declarationId) {
            declaration = d;
            break;
          }
        }
        if (declaration == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.search_off, title: 'Declaration not found'),
          );
        }
        return _DetailScaffold(declaration: declaration);
      },
    );
  }
}

class _DetailScaffold extends ConsumerWidget {
  const _DetailScaffold({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(declaration.cropName),
          actions: [
            if (declaration.status != DeclarationStatus.harvested)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        DeclarationFormScreen(existing: declaration))),
              ),
            _MoreMenu(declaration: declaration),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Financials'),
              Tab(text: 'Harvest'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(declaration: declaration),
            _FinancialsTab(declaration: declaration),
            _HarvestTab(declaration: declaration),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete declaration?'),
              content: const Text(
                  'This removes the declaration and its forecasts. This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            await ref
                .read(appActionsProvider)
                .deleteDeclaration(declaration.id);
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete'),
              contentPadding: EdgeInsets.zero),
        ),
      ],
    );
  }
}

// ── Overview tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saturationAsync = ref.watch(saturationProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Declaration',
          icon: Icons.description_outlined,
          trailing: StatusChip.declaration(declaration.status, dense: true),
          child: Column(
            children: [
              InfoRow(label: 'Crop', value: declaration.cropName),
              InfoRow(label: 'Variety', value: declaration.variety),
              InfoRow(label: 'Area', value: Fmt.area(declaration.areaHa)),
              InfoRow(label: 'Barangay', value: declaration.barangay),
              InfoRow(
                  label: 'Planting date',
                  value: Fmt.date(declaration.plantingDate)),
              InfoRow(
                  label: 'Expected harvest',
                  value: Fmt.date(declaration.expectedHarvestDate)),
              InfoRow(
                  label: 'Expected yield',
                  value: Fmt.weightKg(declaration.expectedYieldKg)),
              InfoRow(
                  label: 'Projected price',
                  value: '${Fmt.peso(declaration.effectivePricePerKg)}/kg'),
              if (declaration.companionCropIds.isNotEmpty)
                InfoRow(
                    label: 'Intercropping',
                    value: declaration.companionCropIds
                        .map((id) => id.replaceAll('_', ' '))
                        .join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CycleProgress(declaration: declaration),
        const SizedBox(height: 12),
        saturationAsync.maybeWhen(
          orElse: () => const SizedBox.shrink(),
          data: (results) {
            final r = results.firstWhere(
              (e) => e.cropId == declaration.cropId,
              orElse: () => SaturationEngine.forCrop(
                  cropId: declaration.cropId, declarations: const []),
            );
            return _SaturationDetail(result: r);
          },
        ),
      ],
    );
  }
}

/// Visual stepper of the BAW → Technician → MAO validation chain.
/// Where this planting is in its growth cycle, plus how much of the scheduled
/// work has been done. This replaces the old BAW → Technician → MAO validation
/// stepper: nobody approves a declaration any more, so the useful progress to
/// show is the crop's own, not a queue position.
class _CycleProgress extends ConsumerWidget {
  const _CycleProgress({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agronomy = ref.watch(agronomyDatasetProvider);
    final stages = CropCalendarEngine.stages(
        declaration: declaration, agronomy: agronomy);
    final current = CropCalendarEngine.currentStage(
        declaration: declaration, agronomy: agronomy);
    final plannedAsync =
        ref.watch(plannedForDeclarationProvider(declaration.id));

    return SectionCard(
      title: 'Growth cycle',
      icon: Icons.timeline,
      trailing: current == null
          ? null
          : StatusChip(
              label: current.label,
              color: AppColors.primary,
              dense: true,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stages.isEmpty)
            Text('No growth-stage data bundled for this crop.',
                style: theme.textTheme.bodySmall)
          else
            for (final s in stages)
              _StageRow(
                stage: s,
                isCurrent: current != null && current.stage == s.stage,
              ),
          plannedAsync.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (activities) {
              if (activities.isEmpty) return const SizedBox.shrink();
              final done = activities
                  .where((a) => a.status == PlannedActivityStatus.done)
                  .length;
              final overdue =
                  activities.where((a) => a.isOverdue()).length;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatioBar(
                      value: done / activities.length,
                      color: AppColors.success,
                      height: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$done of ${activities.length} scheduled activities done'
                      '${overdue > 0 ? ' • $overdue overdue' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.isCurrent});
  final CycleStage stage;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final past = stage.endsOn.isBefore(DateTime.now());
    final color = isCurrent
        ? AppColors.primary
        : past
            ? AppColors.success
            : theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stage.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: isCurrent ? AppColors.primary : null,
              ),
            ),
          ),
          Text(
            '${Fmt.dateShort(stage.startsOn)} – ${Fmt.dateShort(stage.endsOn)}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SaturationDetail extends StatelessWidget {
  const _SaturationDetail({required this.result});
  final SaturationResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.level) {
      SaturationLevel.high => AppColors.riskHigh,
      SaturationLevel.moderate => AppColors.riskModerate,
      SaturationLevel.low => AppColors.riskLow,
    };
    return SectionCard(
      title: 'Market saturation for ${result.cropName}',
      icon: Icons.balance,
      trailing: StatusChip.saturation(result.level, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: MetricTile(
                      label: 'Expected supply',
                      value: Fmt.tons(result.expectedSupplyTons),
                      color: color)),
              const SizedBox(width: 10),
              Expanded(
                  child: MetricTile(
                      label: 'Market demand',
                      value: Fmt.tons(result.demandTons),
                      color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 12),
          RatioBar(value: result.index / 2, color: color, height: 12),
          const SizedBox(height: 8),
          Text(
            'Saturation Index ${result.index.toStringAsFixed(2)} • '
            '${result.contributingDeclarations} declarations contributing'
            '${result.surplusTons > 0 ? ' • projected surplus ${Fmt.tons(result.surplusTons)}' : ''}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Financials tab (Objective 2) ─────────────────────────────────────────────

class _FinancialsTab extends ConsumerWidget {
  const _FinancialsTab({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync =
        ref.watch(expensesForDeclarationProvider(declaration.id));
    final cal = ref.watch(calibrationProvider)[declaration.cropId];

    return AsyncValueView(
      value: expensesAsync,
      onRetry: () =>
          ref.invalidate(expensesForDeclarationProvider(declaration.id)),
      data: (expenses) {
        final spent = FinancialEngine.totalOf(expenses);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CostToDateCard(
              declaration: declaration,
              spent: spent,
              expectedCost: (cal?.totalCostPerHa ?? 45000) * declaration.areaHa,
              expenseCount: expenses.length,
            ),
            const SizedBox(height: 12),
            if (cal != null) ...[
              _PriceCalibrationCard(cal: cal),
              const SizedBox(height: 12),
            ],
            _ExpensesCard(declaration: declaration, expenses: expenses),
            const SizedBox(height: 12),
            const _RealisedNotice(),
          ],
        );
      },
    );
  }
}

/// Money actually spent so far, against the surveyed cost of production for a
/// parcel this size — a real running total, not a forecast.
class _CostToDateCard extends StatelessWidget {
  const _CostToDateCard({
    required this.declaration,
    required this.spent,
    required this.expectedCost,
    required this.expenseCount,
  });

  final CropDeclaration declaration;
  final double spent;
  final double expectedCost;
  final int expenseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = expectedCost <= 0 ? 0.0 : (spent / expectedCost).clamp(0, 1.5);
    final over = spent > expectedCost;

    return SectionCard(
      title: 'Cost to date',
      subtitle: 'Recorded spending on this planting',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Spent so far',
                  value: Fmt.peso(spent),
                  icon: Icons.payments,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricTile(
                  label: 'Typical for ${Fmt.area(declaration.areaHa)}',
                  value: Fmt.pesoCompact(expectedCost),
                  icon: Icons.straighten,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RatioBar(
            value: ratio.toDouble().clamp(0.0, 1.0),
            color: over ? AppColors.warning : AppColors.success,
            height: 10,
          ),
          const SizedBox(height: 8),
          Text(
            expenseCount == 0
                ? 'No costs recorded yet. Log a farm activity and add its cost '
                    'in the same entry — it posts here automatically.'
                : over
                    ? '$expenseCount entries. Spending is above the surveyed '
                        'cost of production for this area.'
                    : '$expenseCount entries recorded '
                        '(${Fmt.percent(ratio.toDouble())} of typical cost).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Explains where profitability now appears, so its absence here does not read
/// as something missing.
class _RealisedNotice extends StatelessWidget {
  const _RealisedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Profit and ROI appear on the Harvest tab once you record the '
              'actual yield and selling price. Before planting, the outlook '
              'for a crop is shown on the declaration form.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.result, required this.isActual});
  final FinancialResult result;
  final bool isActual;

  @override
  Widget build(BuildContext context) {
    final netColor = result.isProfitable ? AppColors.success : AppColors.danger;
    return SectionCard(
      title: isActual ? 'Realized Profit & Loss' : 'Financial forecast',
      subtitle: isActual
          ? 'Based on actual harvest results'
          : 'Pre-planting projection',
      icon: Icons.query_stats,
      child: Column(
        children: [
          MetricGrid(
            columns: 2,
            spacing: 10,
            children: [
              MetricTile(
                  label: 'Projected revenue',
                  value: Fmt.pesoCompact(result.revenue),
                  icon: Icons.trending_up,
                  color: AppColors.success),
              MetricTile(
                  label: 'Total expenses',
                  value: Fmt.pesoCompact(result.totalExpenses),
                  icon: Icons.trending_down,
                  color: AppColors.danger),
              MetricTile(
                  label: 'Net income',
                  value: Fmt.pesoCompact(result.netIncome),
                  icon: Icons.account_balance_wallet,
                  color: netColor),
              MetricTile(
                  label: 'Return on Investment',
                  value: Fmt.percentValue(result.roi * 100),
                  icon: Icons.percent,
                  color: result.roi >= 0 ? AppColors.success : AppColors.danger),
            ],
          ),
          const Divider(height: 24),
          InfoRow(
              label: 'Profit margin',
              value: Fmt.percentValue(result.profitMargin * 100)),
          InfoRow(
              label: 'Net income per hectare',
              value: Fmt.peso(result.netIncomePerHa)),
          InfoRow(
              label: 'Cost per hectare', value: Fmt.peso(result.costPerHa)),
        ],
      ),
    );
  }
}

class _BreakEvenCard extends StatelessWidget {
  const _BreakEvenCard({required this.result});
  final FinancialResult result;

  @override
  Widget build(BuildContext context) {
    final safety = result.marginOfSafety.clamp(0.0, 1.0);
    return SectionCard(
      title: 'Break-even analysis',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
              label: 'Break-even yield',
              value: Fmt.weightKg(result.breakEvenYieldKg),
              icon: Icons.scale),
          InfoRow(
              label: 'Break-even price',
              value: '${Fmt.peso(result.breakEvenPricePerKg)}/kg',
              icon: Icons.sell_outlined),
          const SizedBox(height: 10),
          Text('Margin of safety: ${Fmt.percentValue(safety * 100)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          RatioBar(
            value: safety,
            color: safety > 0.3 ? AppColors.success : AppColors.warning,
            height: 12,
          ),
          const SizedBox(height: 6),
          Text(
            'Expected yield exceeds the break-even point by '
            '${Fmt.weightKg((result.yieldKg - result.breakEvenYieldKg).clamp(0, double.infinity))}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Surfaces the dataset-derived price parameters behind the forecast, making
/// the calibration visible to the farmer (and the thesis panel).
class _PriceCalibrationCard extends StatelessWidget {
  const _PriceCalibrationCard({required this.cal});
  final CropCalibration cal;

  @override
  Widget build(BuildContext context) {
    final volatility = cal.priceCoefficientOfVariation * 100;
    return SectionCard(
      title: 'Price calibration',
      subtitle: 'Derived from 36 months of market data',
      icon: Icons.insights,
      child: Column(
        children: [
          InfoRow(
              label: 'Baseline price (12-mo avg)',
              value: '${Fmt.peso(cal.baselinePricePerKg)}/kg',
              emphasize: true),
          InfoRow(
              label: 'Observed range (P10–P90)',
              value: '${Fmt.peso(cal.priceP10)} – ${Fmt.peso(cal.priceP90)}'),
          InfoRow(
              label: 'Price volatility',
              value: Fmt.percentValue(volatility),
              valueColor: volatility > 15 ? AppColors.warning : AppColors.success),
          InfoRow(
              label: 'Cost of production',
              value: '${Fmt.peso(cal.totalCostPerHa)}/ha'),
          InfoRow(
              label: 'Calibrated demand',
              value: Fmt.tons(cal.annualDemandTons)),
        ],
      ),
    );
  }
}

class _ExpensesCard extends ConsumerWidget {
  const _ExpensesCard({required this.declaration, required this.expenses});
  final CropDeclaration declaration;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Expense ledger',
      subtitle: '${expenses.length} entries • ${Fmt.peso(FinancialEngine.totalOf(expenses))}',
      icon: Icons.receipt_long,
      trailing: IconButton.filledTonal(
        icon: const Icon(Icons.add),
        onPressed: () => showExpenseSheet(context, ref, declaration.id),
      ),
      child: Column(
        children: [
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'No expenses logged. Add fertilizer, labor, and input costs to track your real P&L.',
                  textAlign: TextAlign.center),
            )
          else ...[
            ExpensePieChart(
                byCategory: FinancialEngine.projection(
              expectedYieldKg: 0,
              projectedPricePerKg: 0,
              areaHa: 1,
              expenses: expenses,
            ).expensesByCategory),
            const Divider(height: 24),
            for (final e in expenses)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.danger,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) =>
                    ref.read(appActionsProvider).deleteExpense(e),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(e.category.icon, color: AppColors.secondary),
                  title: Text(e.description,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${e.category.label} • ${Fmt.dateShort(e.incurredOn)}'),
                  trailing: Text(Fmt.peso(e.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Harvest tab ──────────────────────────────────────────────────────────────

class _HarvestTab extends ConsumerWidget {
  const _HarvestTab({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync =
        ref.watch(productionForDeclarationProvider(declaration.id));
    final expensesAsync =
        ref.watch(expensesForDeclarationProvider(declaration.id));

    return AsyncValueView(
      value: reportAsync,
      onRetry: () =>
          ref.invalidate(productionForDeclarationProvider(declaration.id)),
      data: (report) {
        if (report == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Post-harvest report',
                icon: Icons.agriculture,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Once you harvest ${declaration.cropName}, record the actual '
                      'yield and selling price to compute your realized Profit & Loss.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => showProductionReportSheet(
                          context, ref, declaration),
                      icon: const Icon(Icons.add_chart),
                      label: const Text('Record harvest results'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return expensesAsync.maybeWhen(
          orElse: () => const Center(child: CircularProgressIndicator()),
          data: (expenses) {
            final realized = FinancialEngine.realized(
              report: report,
              areaHa: declaration.areaHa,
              expenses: expenses,
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Harvest results',
                  icon: Icons.agriculture,
                  child: Column(
                    children: [
                      InfoRow(
                          label: 'Actual yield',
                          value: Fmt.weightKg(report.actualYieldKg)),
                      InfoRow(
                          label: 'Actual price',
                          value: '${Fmt.peso(report.actualPricePerKg)}/kg'),
                      InfoRow(
                          label: 'Harvested on',
                          value: Fmt.date(report.harvestedOn)),
                      if (report.lossKg > 0)
                        InfoRow(
                            label: 'Recorded loss',
                            value: Fmt.weightKg(report.lossKg)),
                      InfoRow(
                          label: 'Sold to',
                          value: report.soldToChannel.label),
                      if (report.buyerName != null)
                        InfoRow(label: 'Buyer', value: report.buyerName!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ForecastCard(result: realized, isActual: true),
                const SizedBox(height: 12),
                // Break-even is meaningful here, against real numbers, rather
                // than against a pre-planting guess.
                _BreakEvenCard(result: realized),
                const SizedBox(height: 12),
                _PlanVsActual(declaration: declaration, report: report),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlanVsActual extends StatelessWidget {
  const _PlanVsActual({required this.declaration, required this.report});
  final CropDeclaration declaration;
  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final yieldDelta = report.actualYieldKg - declaration.expectedYieldKg;
    final priceDelta =
        report.actualPricePerKg - declaration.effectivePricePerKg;
    return SectionCard(
      title: 'Plan vs. actual',
      icon: Icons.compare_arrows,
      child: Column(
        children: [
          InfoRow(
            label: 'Yield variance',
            value:
                '${yieldDelta >= 0 ? '+' : ''}${Fmt.weightKg(yieldDelta)}',
            valueColor: yieldDelta >= 0 ? AppColors.success : AppColors.danger,
          ),
          InfoRow(
            label: 'Price variance',
            value:
                '${priceDelta >= 0 ? '+' : ''}${Fmt.peso(priceDelta)}/kg',
            valueColor: priceDelta >= 0 ? AppColors.success : AppColors.danger,
          ),
        ],
      ),
    );
  }
}
