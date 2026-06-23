import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/saturation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/section_card.dart';
import '../../models/cooperative.dart';
import '../../providers/app_actions.dart';
import '../../providers/data_providers.dart';
import 'market_channel_sheet.dart';

/// Surplus management (Objective 3): predicted surplus per crop matched against
/// the cooperative's buy-back programs and alternative market channels.
class SurplusScreen extends ConsumerWidget {
  const SurplusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saturationAsync = ref.watch(saturationProvider);
    final channelsAsync = ref.watch(marketChannelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Surplus & Buy-back')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMarketChannelSheet(context, ref),
        icon: const Icon(Icons.add_business),
        label: const Text('Add channel'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(saturationProvider);
          ref.invalidate(marketChannelsProvider);
        },
        child: AsyncValueView(
          value: saturationAsync,
          onRetry: () => ref.invalidate(saturationProvider),
          data: (saturation) {
            final surplusCrops = saturation
                .where((s) => s.surplusTons > 0)
                .toList()
              ..sort((a, b) => b.surplusTons.compareTo(a.surplusTons));

            return channelsAsync.maybeWhen(
              orElse: () => const Center(child: CircularProgressIndicator()),
              data: (channels) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _CapacitySummary(channels: channels, surplus: surplusCrops),
                  const SizedBox(height: 12),
                  _SectionTitle('Predicted surplus routing'),
                  if (surplusCrops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'No surplus predicted. Supply is within demand across all crops.'),
                    )
                  else
                    for (final s in surplusCrops)
                      _SurplusRoutingCard(result: s, channels: channels),
                  const SizedBox(height: 8),
                  _SectionTitle('Buy-back & market channels'),
                  if (channels.isEmpty)
                    EmptyState(
                      icon: Icons.storefront,
                      title: 'No channels yet',
                      message:
                          'Add buy-back programs and alternative market channels '
                          'to route predicted surplus.',
                      actionLabel: 'Add channel',
                      onAction: () => showMarketChannelSheet(context, ref),
                    )
                  else
                    for (final c in channels)
                      _ChannelCard(channel: c),
                ],
              ),
            );
          },
        ),
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

class _CapacitySummary extends StatelessWidget {
  const _CapacitySummary({required this.channels, required this.surplus});
  final List<MarketChannel> channels;
  final List<SaturationResult> surplus;

  @override
  Widget build(BuildContext context) {
    final totalCapacity =
        channels.fold<double>(0, (s, c) => s + c.capacityTons);
    final totalSurplus =
        surplus.fold<double>(0, (s, e) => s + e.surplusTons);
    final covered = totalCapacity >= totalSurplus;
    return SectionCard(
      title: 'Absorption capacity',
      icon: Icons.warehouse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                    label: 'Predicted surplus',
                    value: Fmt.tons(totalSurplus),
                    color: AppColors.riskHigh),
              ),
              Expanded(
                child: _Stat(
                    label: 'Channel capacity',
                    value: Fmt.tons(totalCapacity),
                    color: AppColors.info),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RatioBar(
            value: totalCapacity == 0
                ? 0
                : (totalSurplus / totalCapacity).clamp(0, 1),
            color: covered ? AppColors.success : AppColors.riskHigh,
            height: 12,
          ),
          const SizedBox(height: 8),
          Text(
            covered
                ? 'Channels can absorb the predicted surplus.'
                : 'Surplus exceeds current channel capacity — add buy-back or market channels.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _SurplusRoutingCard extends StatelessWidget {
  const _SurplusRoutingCard({required this.result, required this.channels});
  final SaturationResult result;
  final List<MarketChannel> channels;

  @override
  Widget build(BuildContext context) {
    final matching =
        channels.where((c) => c.cropIds.contains(result.cropId)).toList();
    final matchedCapacity =
        matching.fold<double>(0, (s, c) => s + c.capacityTons);
    final covered = matchedCapacity >= result.surplusTons;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${result.cropName} surplus',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                Text(Fmt.tons(result.surplusTons),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.riskHigh)),
              ],
            ),
            const SizedBox(height: 8),
            if (matching.isEmpty)
              Text(
                'No channel currently accepts ${result.cropName}. Add a buy-back or market channel for it.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Text(
                covered
                    ? 'Route to ${matching.length} channel(s) (capacity ${Fmt.tons(matchedCapacity)}):'
                    : 'Partial coverage — ${Fmt.tons(matchedCapacity)} of ${Fmt.tons(result.surplusTons)}:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in matching)
                    Chip(
                      avatar: Icon(
                          covered ? Icons.check_circle : Icons.swap_horiz,
                          size: 16,
                          color: AppColors.success),
                      label: Text('${c.name} (${Fmt.tons(c.capacityTons)})'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends ConsumerWidget {
  const _ChannelCard({required this.channel});
  final MarketChannel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(channel.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) =>
            ref.read(appActionsProvider).deleteMarketChannel(channel.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.secondary.withValues(alpha: 0.12),
                    child:
                        const Icon(Icons.storefront, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(channel.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(channel.typeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.tons(channel.capacityTons),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (channel.pricePerKg != null)
                        Text('${Fmt.peso(channel.pricePerKg!)}/kg',
                            style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
              if (channel.cropIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final id in channel.cropIds)
                      Chip(
                        label: Text(id.replaceAll('_', ' ')),
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ],
              if (channel.notes != null) ...[
                const SizedBox(height: 8),
                Text(channel.notes!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
