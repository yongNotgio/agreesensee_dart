import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/saturation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// Cooperative overview: forward-looking supply snapshot, member participation,
/// and the most urgent oversupply alerts across the association's barangays.
class CoopDashboardScreen extends ConsumerWidget {
  const CoopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final coopAsync = ref.watch(cooperativeProvider);
    final declarationsAsync = ref.watch(allDeclarationsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allDeclarationsProvider);
          ref.invalidate(cooperativeProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cooperative Portal',
                      style: Theme.of(context).textTheme.bodySmall),
                  coopAsync.maybeWhen(
                    orElse: () => Text(profile?.fullName ?? 'Cooperative',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    data: (coop) => Text(coop?.name ?? 'Cooperative',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: AsyncValueView(
                  value: declarationsAsync,
                  onRetry: () => ref.invalidate(allDeclarationsProvider),
                  data: (declarations) =>
                      _DashboardBody(declarations: declarations),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.declarations});
  final List<CropDeclaration> declarations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coop = ref.watch(cooperativeProvider).valueOrNull;
    final active = declarations.where((d) => d.status.isActive).toList();
    final totalSupply =
        active.fold<double>(0, (s, d) => s + d.expectedYieldTons);
    final memberFarmers = active.map((d) => d.farmerId).toSet().length;

    final saturation = SaturationEngine.forAllCrops(declarations);
    final highRisk =
        saturation.where((s) => s.level == SaturationLevel.high).toList();
    final totalSurplus =
        saturation.fold<double>(0, (s, e) => s + e.surplusTons);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricGrid(
          columns: 2,
          children: [
            MetricTile(
                label: 'Projected supply',
                value: Fmt.tons(totalSupply),
                icon: Icons.inventory_2,
                caption: 'across active declarations'),
            MetricTile(
                label: 'Participating farmers',
                value: '$memberFarmers',
                icon: Icons.groups,
                color: AppColors.secondary,
                caption: coop != null ? 'of ${coop.memberCount} members' : null),
            MetricTile(
                label: 'High-risk crops',
                value: '${highRisk.length}',
                icon: Icons.warning_amber,
                color: highRisk.isEmpty ? AppColors.success : AppColors.riskHigh,
                caption: 'oversupply watch'),
            MetricTile(
                label: 'Projected surplus',
                value: Fmt.tons(totalSurplus),
                icon: Icons.trending_up,
                color: AppColors.tertiary,
                caption: 'above market demand'),
          ],
        ),
        const SizedBox(height: 16),
        if (highRisk.isNotEmpty) ...[
          SectionCard(
            title: 'Oversupply alerts',
            subtitle: 'Coordinate mitigation before harvest',
            icon: Icons.notifications_active,
            child: Column(
              children: [
                for (final r in highRisk) _AlertRow(result: r),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _CongestionCard(),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.result});
  final SaturationResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.priority_high, color: AppColors.riskHigh),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.cropName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    'Supply ${Fmt.tons(result.expectedSupplyTons)} vs demand ${Fmt.tons(result.demandTons)} • surplus ${Fmt.tons(result.surplusTons)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          StatusChip.saturation(result.level, dense: true),
        ],
      ),
    );
  }
}

class _CongestionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(harvestSuggestionsProvider);
    return suggestions.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return SectionCard(
            title: 'Harvest synchronization',
            icon: Icons.sync,
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Member harvests are well distributed. No congestion detected.',
                      style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          );
        }
        return SectionCard(
          title: 'Harvest congestion',
          subtitle: '${list.length} crowded window(s)',
          icon: Icons.sync_problem,
          child: Column(
            children: [
              for (final s in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_busy,
                          color: AppColors.riskHigh, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${s.peak.cropName}: ${s.peak.farmerCount} farmers • ${Fmt.tons(s.peak.volumeTons)} in ${s.peak.weekLabel}. '
                          'Recommend staggering ~${s.suggestedShiftDays} days or routing surplus to buy-back.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
