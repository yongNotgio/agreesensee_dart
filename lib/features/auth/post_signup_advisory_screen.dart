import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/recommendation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/suitability_card.dart';
import '../../models/enums.dart';
import '../../providers/data_providers.dart';

/// Shown once, immediately after a farmer registers.
///
/// A new account used to land on an empty dashboard, which answers none of the
/// questions a farmer actually arrives with. Their barangay is already known at
/// this point, so the app can lead with what is worth planting there this
/// season — no farm record or declaration required.
class PostSignupAdvisoryScreen extends ConsumerWidget {
  const PostSignupAdvisoryScreen({super.key, required this.barangay});

  final String barangay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsForBarangayProvider(barangay));
    final season = Season.forMonth(DateTime.now().month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to AgriSense'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to my dashboard'),
          ),
        ),
      ),
      body: AsyncValueView(
        value: recs,
        onRetry: () =>
            ref.invalidate(recommendationsForBarangayProvider(barangay)),
        data: (list) {
          final top = list.take(4).toList();
          final avoid = list
              .where((r) => r.saturation.level == SaturationLevel.high)
              .take(2)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(barangay: barangay, season: season),
              const SizedBox(height: 16),
              const SuitabilityLegend(),
              const SizedBox(height: 16),
              Text('Best picks for Brgy. $barangay',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final r in top) _RecommendationPreview(rec: r),
              if (avoid.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Currently oversupplied',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Other farmers have already declared enough of these to meet '
                  'local demand. Planting more risks a price collapse at harvest.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (final r in avoid) _AvoidTile(rec: r),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.barangay, required this.season});
  final String barangay;
  final Season season;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.eco, color: AppColors.primary, size: 28),
          const SizedBox(height: 10),
          Text('Your account is ready',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Here is what the data says about planting in Brgy. $barangay '
            'during the ${season.label.toLowerCase()}. AgriSense recommends — '
            'the decision stays yours.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RecommendationPreview extends StatelessWidget {
  const _RecommendationPreview({required this.rec});
  final CropRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final suitability = rec.suitability;
    final theme = Theme.of(context);
    final color = suitability == null
        ? AppColors.primary
        : suitabilityColor(suitability.band);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Text('${rec.scorePercent}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(rec.crop.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                if (suitability != null)
                  StatusChip.suitability(suitability.band, dense: true),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Fact(
                    icon: Icons.scale,
                    label:
                        '≈ ${Fmt.number(rec.expectedYieldPerHa / 1000)} t/ha expected'),
                _Fact(
                    icon: Icons.sell_outlined,
                    label: '${Fmt.peso(rec.baselinePricePerKg)}/kg'),
                _Fact(
                    icon: Icons.schedule,
                    label: '${rec.crop.growthDurationDays}-day cycle'),
              ],
            ),
            const SizedBox(height: 8),
            Text(rec.rationale,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }
}

class _AvoidTile extends StatelessWidget {
  const _AvoidTile({required this.rec});
  final CropRecommendation rec;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.riskHigh.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.riskHigh.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        leading: const Icon(Icons.trending_up, color: AppColors.riskHigh),
        title: Text(rec.crop.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            'Supply is ${rec.saturation.index.toStringAsFixed(2)}× local demand'),
      ),
    );
  }
}
