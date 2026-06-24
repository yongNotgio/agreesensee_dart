import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/financial_engine.dart';
import '../../core/logic/saturation_engine.dart';
import '../../core/logic/scenario_engine.dart';
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
///   • Overview   — declaration data, validation status, market saturation
///   • Financials — projection (ROI, break-even), expenses, scenario analysis
///   • Harvest    — post-harvest production report and realized P&L
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
        if (declaration.reviewerNote != null)
          SectionCard(
            title: 'Validator note',
            icon: Icons.rate_review_outlined,
            child: Text(declaration.reviewerNote!),
          ),
        if (declaration.reviewerNote != null) const SizedBox(height: 12),
        _ValidationTimeline(status: declaration.status),
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
class _ValidationTimeline extends StatelessWidget {
  const _ValidationTimeline({required this.status});
  final DeclarationStatus status;

  static const _steps = [
    (DeclarationStatus.pending, 'Submitted', Icons.send),
    (DeclarationStatus.bawApproved, 'BAW Validation', Icons.verified_user),
    (
      DeclarationStatus.technicianVerified,
      'Technician Review',
      Icons.fact_check
    ),
    (DeclarationStatus.approved, 'MAO Approval', Icons.account_balance),
  ];

  int get _reachedIndex {
    switch (status) {
      case DeclarationStatus.draft:
      case DeclarationStatus.pending:
      case DeclarationStatus.correctionRequested:
        return 0;
      case DeclarationStatus.bawApproved:
        return 1;
      case DeclarationStatus.technicianVerified:
        return 2;
      case DeclarationStatus.approved:
      case DeclarationStatus.harvested:
        return 3;
      case DeclarationStatus.rejected:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (status == DeclarationStatus.rejected) {
      return SectionCard(
        title: 'Validation',
        icon: Icons.cancel,
        child: Row(children: [
          const Icon(Icons.cancel, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text('This declaration was rejected. Edit and resubmit.',
                  style: theme.textTheme.bodyMedium)),
        ]),
      );
    }
    final reached = _reachedIndex;
    return SectionCard(
      title: 'Validation progress',
      icon: Icons.timeline,
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            _TimelineRow(
              label: _steps[i].$2,
              icon: _steps[i].$3,
              done: i <= reached,
              current: i == reached &&
                  status != DeclarationStatus.approved &&
                  status != DeclarationStatus.harvested,
              isLast: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
    required this.isLast,
  });
  final String label;
  final IconData icon;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        done ? AppColors.success : theme.colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.success.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(done ? Icons.check : icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: color),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                color: current ? AppColors.primary : theme.colorScheme.onSurface,
              ),
            ),
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
    // Dataset-calibrated parameters for this crop (cost-of-production and the
    // price/yield scenario bands). Falls back to a flat estimate if absent.
    final cal = ref.watch(calibrationProvider)[declaration.cropId];

    return AsyncValueView(
      value: expensesAsync,
      onRetry: () =>
          ref.invalidate(expensesForDeclarationProvider(declaration.id)),
      data: (expenses) {
        final result = FinancialEngine.projection(
          expectedYieldKg: declaration.expectedYieldKg,
          projectedPricePerKg: declaration.effectivePricePerKg,
          areaHa: declaration.areaHa,
          expenses: expenses,
          estimatedExpensesIfEmpty:
              (cal?.totalCostPerHa ?? 45000) * declaration.areaHa,
        );
        final scenarios = ScenarioEngine.build(
          expectedYieldKg: declaration.expectedYieldKg,
          projectedPricePerKg: declaration.effectivePricePerKg,
          areaHa: declaration.areaHa,
          totalExpenses: result.totalExpenses,
          bestPriceUplift: cal?.bestPriceUplift ?? 0.15,
          bestYieldUplift: cal?.bestYieldUplift ?? 0.10,
          worstPriceDrop: cal?.worstPriceDrop ?? 0.20,
          worstYieldDrop: cal?.worstYieldDrop ?? 0.15,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ForecastCard(result: result, isActual: false),
            const SizedBox(height: 12),
            if (cal != null) ...[
              _PriceCalibrationCard(cal: cal),
              const SizedBox(height: 12),
            ],
            _BreakEvenCard(result: result),
            const SizedBox(height: 12),
            _ScenarioCard(scenarios: scenarios),
            const SizedBox(height: 12),
            _ExpensesCard(declaration: declaration, expenses: expenses),
          ],
        );
      },
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

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenarios});
  final List<Scenario> scenarios;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Risk & scenario analysis',
      subtitle: 'Net income under price/yield shocks',
      icon: Icons.show_chart,
      child: Column(
        children: [
          ScenarioBarChart(scenarios: scenarios),
          const SizedBox(height: 12),
          for (final s in scenarios)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.kind.label} (price ×${s.priceFactor.toStringAsFixed(2)}, yield ×${s.yieldFactor.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(Fmt.peso(s.netIncome),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: s.netIncome >= 0
                              ? AppColors.success
                              : AppColors.danger)),
                ],
              ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ForecastCard(result: realized, isActual: true),
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
