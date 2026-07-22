import 'package:flutter/material.dart';

import '../../../core/logic/recommendation_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';

/// Live risk assessment shown on the declaration form as the farmer fills it in.
///
/// With the MAO approval chain gone, nothing downstream reviews a declaration —
/// so the warning has to arrive *before* the commitment, at the moment the crop,
/// area, and barangay are chosen. This is also where the system-derived yield
/// and price appear: the farmer no longer types those numbers, they read them.
class PreDeclarationRiskPanel extends StatelessWidget {
  const PreDeclarationRiskPanel({
    super.key,
    required this.risk,
    required this.areaHa,
  });

  final DeclarationRisk? risk;
  final double areaHa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (risk == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.query_stats,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter an area and barangay to see the market and land outlook '
                'for this crop.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final r = risk!;
    final color = _verdictColor(r.verdict);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_verdictIcon(r.verdict), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.verdict.label,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              StatusChip.saturation(r.saturation.level, dense: true),
            ],
          ),
          const SizedBox(height: 12),

          // The numbers the farmer used to be asked to guess.
          _DerivedFigures(risk: r),
          const SizedBox(height: 12),

          for (final reason in r.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(reason, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),

          if (r.isHigh && r.alternatives.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: color.withValues(alpha: 0.25)),
            const SizedBox(height: 6),
            Text('Consider instead',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final alt in r.alternatives)
                  Chip(
                    avatar: const Icon(Icons.swap_horiz,
                        size: 15, color: AppColors.success),
                    label: Text(
                        '${alt.crop.name} • ${alt.scorePercent}% match'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _verdictColor(RiskVerdict v) => switch (v) {
        RiskVerdict.low => AppColors.success,
        RiskVerdict.caution => AppColors.riskModerate,
        RiskVerdict.high => AppColors.riskHigh,
      };

  static IconData _verdictIcon(RiskVerdict v) => switch (v) {
        RiskVerdict.low => Icons.check_circle,
        RiskVerdict.caution => Icons.info,
        RiskVerdict.high => Icons.warning_amber,
      };
}

/// The system's expectation for this parcel — read-only by design.
class _DerivedFigures extends StatelessWidget {
  const _DerivedFigures({required this.risk});
  final DeclarationRisk risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Expected yield',
                  value: Fmt.weightKg(risk.expectedYieldKg),
                  icon: Icons.scale,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Farmgate price',
                  value: '${Fmt.peso(risk.projectedPricePerKg)}/kg',
                  icon: Icons.sell_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Projected revenue',
                  value: Fmt.pesoCompact(risk.projectedRevenue),
                  icon: Icons.payments_outlined,
                  emphasize: true,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Demand basis',
                  value: risk.saturation.demand.provenance,
                  icon: Icons.groups_outlined,
                  small: true,
                ),
              ),
            ],
          ),
          if (risk.hasVolatilityBand) ...[
            const SizedBox(height: 10),
            _RevenueBand(risk: risk),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Calculated from 3 years of price data and your barangay\'s '
                  'observed yields — not an estimate you need to supply.',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The revenue spread this crop's own price and yield history exposes the
/// farmer to. A single point estimate hides the risk; tomato and corn can
/// project the same expected revenue with very different downside.
class _RevenueBand extends StatelessWidget {
  const _RevenueBand({required this.risk});
  final DeclarationRisk risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spread = risk.projectedRevenue <= 0
        ? 0.0
        : (risk.bestCaseRevenue - risk.worstCaseRevenue) /
            risk.projectedRevenue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stacked_line_chart,
                  size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text('If prices move',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.trending_down,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text(Fmt.pesoCompact(risk.worstCaseRevenue),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(Fmt.pesoCompact(risk.bestCaseRevenue),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                    const SizedBox(width: 4),
                    const Icon(Icons.trending_up,
                        size: 14, color: AppColors.success),
                  ],
                ),
              ),
            ],
          ),
          if (spread > 0.5) ...[
            const SizedBox(height: 4),
            Text(
              'This crop\'s price swings widely — plan for the low end.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.riskModerate),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.small = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: small ? 11 : (emphasize ? 18 : 15),
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
            color: emphasize ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}
