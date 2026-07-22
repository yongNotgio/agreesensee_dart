import 'package:flutter/material.dart';

import '../../core/logic/suitability_engine.dart';
import '../../models/enums.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';
import 'status_chip.dart';

/// Colour for a land-suitability band, shared by the card, the list, and the
/// heat-map grid so one crop reads the same everywhere it appears.
Color suitabilityColor(SuitabilityBand band) => switch (band) {
      SuitabilityBand.verySuitable => AppColors.success,
      SuitabilityBand.suitable => AppColors.riskLow,
      SuitabilityBand.moderate => AppColors.riskModerate,
      SuitabilityBand.marginal => AppColors.riskHigh,
    };

/// One crop's suitability in a barangay: band, yield index, and the reason.
class SuitabilityCard extends StatelessWidget {
  const SuitabilityCard({
    super.key,
    required this.result,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final SuitabilityResult result;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = suitabilityColor(result.band);

    return Card(
      margin: EdgeInsets.only(bottom: dense ? 8 : 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IndexBadge(percent: result.percent, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.cropName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        if (result.terrain.isNotEmpty)
                          Text(
                            '${result.terrain} • ${result.dominantSoil.replaceAll('_', ' ')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  trailing ??
                      StatusChip.suitability(result.band, dense: true),
                ],
              ),
              const SizedBox(height: 10),
              RatioBar(value: result.yieldIndex, color: color, height: 7),
              const SizedBox(height: 8),
              Text(
                result.rationale,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (!result.isMapped) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Estimated from soil type — no barangay-level record yet.',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.percent, required this.color});
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$percent',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17, color: color)),
          Text('%',
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Explains what the yield index means, so a farmer reading "72%" knows it is
/// a share of attainable yield and not a probability or a score out of 100.
class SuitabilityLegend extends StatelessWidget {
  const SuitabilityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The percentage is how much of a crop\'s attainable yield is '
                  'actually reached in this barangay.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final band in SuitabilityBand.values)
                _BandKey(band: band),
            ],
          ),
        ],
      ),
    );
  }
}

class _BandKey extends StatelessWidget {
  const _BandKey({required this.band});
  final SuitabilityBand band;

  @override
  Widget build(BuildContext context) {
    final color = suitabilityColor(band);
    final range = switch (band) {
      SuitabilityBand.verySuitable => '80%+',
      SuitabilityBand.suitable => '70–79%',
      SuitabilityBand.moderate => '50–69%',
      SuitabilityBand.marginal => 'below 50%',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('${band.label} ($range)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
