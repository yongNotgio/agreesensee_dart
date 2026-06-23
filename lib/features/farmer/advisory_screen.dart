import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/harvest_sync_engine.dart';
import '../../core/logic/recommendation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/enums.dart';
import '../../providers/data_providers.dart';

/// Farmer advisory: crop recommendations (single + intercropping) and harvest
/// synchronization alerts. Implements study Objective 1.
class AdvisoryScreen extends ConsumerWidget {
  const AdvisoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Advisory'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Recommendations'),
            Tab(text: 'Harvest Sync'),
          ]),
        ),
        body: TabBarView(
          children: [
            _RecommendationsTab(),
            _HarvestSyncTab(),
          ],
        ),
      ),
    );
  }
}

class _RecommendationsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider);
    final intercrops = ref.watch(intercropProvider);
    final season = Season.forMonth(DateTime.now().month);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allDeclarationsProvider),
      child: AsyncValueView(
        value: recs,
        onRetry: () => ref.invalidate(recommendationsProvider),
        data: (list) {
          final top = list.take(5).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ranked for the current ${season.label} using land suitability, '
                        'seasonal fit, market saturation, and projected profit.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionTitle('Best single-crop strategies'),
              for (final r in top) _RecommendationCard(rec: r),
              const SizedBox(height: 8),
              _SectionTitle('Intercropping (mix-and-match)'),
              intercrops.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                data: (pairs) {
                  if (pairs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No strong intercropping pairs right now.'),
                    );
                  }
                  return Column(
                      children: [for (final p in pairs) _IntercropCard(pair: p)]);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec});
  final CropRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ScoreBadge(score: rec.score),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rec.crop.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(rec.crop.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusChip.saturation(rec.saturation.level, dense: true),
              ],
            ),
            const SizedBox(height: 12),
            _SignalBars(rec: rec),
            const SizedBox(height: 10),
            Text(rec.rationale,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                _Pill(
                    icon: Icons.payments,
                    label: '≈ ${Fmt.pesoCompact(rec.projectedNetPerHa)}/ha net'),
                const SizedBox(width: 8),
                _Pill(
                    icon: Icons.schedule,
                    label: '${rec.crop.growthDurationDays}-day cycle'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;
  @override
  Widget build(BuildContext context) {
    final color = score >= 0.7
        ? AppColors.success
        : score >= 0.5
            ? AppColors.riskModerate
            : AppColors.danger;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text('${(score * 100).round()}',
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18, color: color)),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rec});
  final CropRecommendation rec;
  @override
  Widget build(BuildContext context) {
    Widget bar(String label, double value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                  width: 78,
                  child: Text(label,
                      style: const TextStyle(fontSize: 11))),
              Expanded(child: RatioBar(value: value, color: color, height: 7)),
              const SizedBox(width: 8),
              Text('${(value * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Column(
      children: [
        bar('Suitability', rec.suitabilityScore, AppColors.primary),
        bar('Season', rec.seasonScore, AppColors.secondary),
        bar('Low saturation', rec.saturationScore, AppColors.info),
        bar('Profitability', rec.profitabilityScore, AppColors.tertiary),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
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
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }
}

class _IntercropCard extends StatelessWidget {
  const _IntercropCard({required this.pair});
  final IntercropRecommendation pair;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grass, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${pair.primary.name} + ${pair.companion.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                _ScoreBadge(score: pair.combinedScore),
              ],
            ),
            const SizedBox(height: 8),
            Text(pair.rationale,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Harvest synchronization tab ──────────────────────────────────────────────

class _HarvestSyncTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaks = ref.watch(harvestPeaksProvider);
    final suggestions = ref.watch(harvestSuggestionsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allDeclarationsProvider),
      child: AsyncValueView(
        value: peaks,
        onRetry: () => ref.invalidate(harvestPeaksProvider),
        data: (peakList) {
          final congested = peakList.where((p) => p.isCongested).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Harvest synchronization',
                subtitle: 'Avoid simultaneous market dumping',
                icon: Icons.sync,
                child: Text(
                  congested.isEmpty
                      ? 'No congested harvest windows detected. Your planned harvests are well spread across the calendar.'
                      : '${congested.length} crowded harvest window(s) detected. Staggering your planting can protect prices.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              suggestions.maybeWhen(
                orElse: () => const SizedBox.shrink(),
                data: (list) => Column(
                    children: [for (final s in list) _SuggestionCard(s: s)]),
              ),
              _SectionTitle('Upcoming harvest peaks'),
              ...peakList
                  .where((p) => p.volumeTons > 0)
                  .map((p) => _PeakTile(peak: p)),
              if (peakList.where((p) => p.volumeTons > 0).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No upcoming harvests recorded yet.'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.s});
  final SyncSuggestion s;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.riskHigh.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.riskHigh.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber, color: AppColors.riskHigh),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.peak.cropName} • ${s.peak.weekLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.message,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakTile extends StatelessWidget {
  const _PeakTile({required this.peak});
  final HarvestPeak peak;
  @override
  Widget build(BuildContext context) {
    final color = peak.isCongested ? AppColors.riskHigh : AppColors.success;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(peak.isCongested ? Icons.priority_high : Icons.event,
              color: color),
        ),
        title: Text('${peak.cropName} • ${Fmt.tons(peak.volumeTons)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            'Week of ${Fmt.dateShort(peak.weekStart)} • ${peak.farmerCount} farmer(s)'),
        trailing: peak.isCongested
            ? const StatusChip(
                label: 'Congested', color: AppColors.riskHigh, dense: true)
            : null,
      ),
    );
  }
}
