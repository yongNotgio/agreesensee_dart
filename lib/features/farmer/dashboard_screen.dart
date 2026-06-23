import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/saturation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';
import 'declaration_detail_screen.dart';
import 'declaration_form_screen.dart';

/// Farmer home: a glanceable summary of declarations, a financial snapshot, the
/// nearest harvest, and the highest-risk saturation alert.
class FarmerDashboardScreen extends ConsumerWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final declarations = ref.watch(declarationsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(declarationsProvider);
          ref.invalidate(allDeclarationsProvider);
          ref.invalidate(farmerExpensesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Magandang araw,',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(profile?.fullName ?? 'Farmer',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(profile?.initials ?? 'F',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: AsyncValueView(
                  value: declarations,
                  onRetry: () => ref.invalidate(declarationsProvider),
                  data: (list) => _DashboardBody(declarations: list),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeclarationFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Declare Crop'),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.declarations});
  final List<CropDeclaration> declarations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = declarations.where((d) => d.status.isActive).toList();
    final pending =
        declarations.where((d) => d.status == DeclarationStatus.pending).length;
    final projectedRevenue =
        active.fold<double>(0, (s, d) => s + d.projectedRevenue);
    final totalArea = active.fold<double>(0, (s, d) => s + d.areaHa);

    // Nearest upcoming harvest.
    final upcoming = [...active]
      ..sort((a, b) => a.expectedHarvestDate.compareTo(b.expectedHarvestDate));
    final nextHarvest = upcoming.isEmpty ? null : upcoming.first;

    if (declarations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: EmptyState(
          icon: Icons.eco,
          title: 'No crop declarations yet',
          message:
              'Declare what you plan to plant so AgriSense can forecast supply, '
              'check market saturation, and recommend the best strategy.',
          actionLabel: 'Declare your first crop',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const DeclarationFormScreen())),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI grid.
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            MetricTile(
              label: 'Active crops',
              value: '${active.length}',
              icon: Icons.eco,
              caption: pending > 0 ? '$pending pending validation' : 'All clear',
            ),
            MetricTile(
              label: 'Planted area',
              value: Fmt.area(totalArea),
              icon: Icons.crop_landscape,
              color: AppColors.secondary,
            ),
            MetricTile(
              label: 'Projected revenue',
              value: Fmt.pesoCompact(projectedRevenue),
              icon: Icons.payments,
              color: AppColors.tertiary,
              caption: 'across active declarations',
            ),
            MetricTile(
              label: 'Next harvest',
              value: nextHarvest == null
                  ? '—'
                  : Fmt.relativeDays(nextHarvest.expectedHarvestDate),
              icon: Icons.event,
              color: AppColors.info,
              caption: nextHarvest?.cropName,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SaturationAlert(),
        const SizedBox(height: 16),
        _ActiveDeclarations(active: active.take(3).toList()),
      ],
    );
  }
}

/// Surfaces the single highest-risk saturation result so the farmer is warned
/// before planting (Objective 1).
class _SaturationAlert extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saturation = ref.watch(saturationProvider);
    return saturation.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (results) {
        final highest = results.isEmpty ? null : results.first;
        if (highest == null || highest.level == SaturationLevel.low) {
          return SectionCard(
            title: 'Market saturation',
            icon: Icons.balance,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No high-risk oversupply detected for your area right now. '
                    'Good time to plan plantings.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }
        return _SaturationCard(result: highest);
      },
    );
  }
}

class _SaturationCard extends StatelessWidget {
  const _SaturationCard({required this.result});
  final SaturationResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.level) {
      SaturationLevel.high => AppColors.riskHigh,
      SaturationLevel.moderate => AppColors.riskModerate,
      SaturationLevel.low => AppColors.riskLow,
    };
    return SectionCard(
      title: 'Oversupply watch',
      icon: Icons.warning_amber,
      trailing: StatusChip.saturation(result.level, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.cropName} — expected supply ${Fmt.tons(result.expectedSupplyTons)} '
            'vs demand ${Fmt.tons(result.demandTons)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          RatioBar(value: result.index / 2, color: color, height: 12),
          const SizedBox(height: 8),
          Text(
            'Saturation Index ${result.index.toStringAsFixed(2)} '
            '(${result.contributingDeclarations} active declarations). '
            '${result.level == SaturationLevel.high ? 'Consider an alternative crop in the Advisory tab.' : 'Supply is near balance.'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ActiveDeclarations extends StatelessWidget {
  const _ActiveDeclarations({required this.active});
  final List<CropDeclaration> active;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Active declarations',
      icon: Icons.eco,
      child: Column(
        children: [
          for (final d in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.spa, color: AppColors.primary),
              ),
              title: Text('${d.cropName} • ${d.variety}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${Fmt.area(d.areaHa)} • harvest ${Fmt.dateShort(d.expectedHarvestDate)}'),
              trailing: StatusChip.declaration(d.status, dense: true),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DeclarationDetailScreen(declarationId: d.id))),
            ),
        ],
      ),
    );
  }
}
