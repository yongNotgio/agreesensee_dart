import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logic/harvest_sync_engine.dart';
import '../../core/logic/saturation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/crop_declaration.dart';
import '../../providers/data_providers.dart';

/// Forward-looking supply projection (Objective 3): a weekly harvest-volume
/// time series per crop plotted against market demand, plus the full saturation
/// table the cooperative uses to anticipate gluts.
class SupplyProjectionScreen extends ConsumerStatefulWidget {
  const SupplyProjectionScreen({super.key});

  @override
  ConsumerState<SupplyProjectionScreen> createState() =>
      _SupplyProjectionScreenState();
}

class _SupplyProjectionScreenState
    extends ConsumerState<SupplyProjectionScreen> {
  String _cropId = CropCatalog.crops.first.id;

  @override
  Widget build(BuildContext context) {
    final declarationsAsync = ref.watch(allDeclarationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Supply Projection')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(allDeclarationsProvider),
        child: AsyncValueView(
          value: declarationsAsync,
          onRetry: () => ref.invalidate(allDeclarationsProvider),
          data: (declarations) {
            final projection = HarvestSyncEngine.projectionForCrop(
                declarations, _cropId,
                weeks: 12);
            final saturation =
                SaturationEngine.forAllCrops(declarations);
            final selected = saturation.firstWhere(
              (s) => s.cropId == _cropId,
              orElse: () => SaturationEngine.forCrop(
                  cropId: _cropId, declarations: declarations),
            );
            // Convert the demand (annual-ish baseline) into a weekly reference
            // line proportional to the chart horizon for visual comparison.
            final weeklyDemandRef = selected.demandTons / 12;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CropSelector(
                  value: _cropId,
                  onChanged: (v) => setState(() => _cropId = v),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '${CropCatalog.nameFor(_cropId)} — 12-week harvest curve',
                  subtitle: 'Projected weekly volume vs. demand reference',
                  icon: Icons.stacked_line_chart,
                  trailing: StatusChip.saturation(selected.level, dense: true),
                  child: Column(
                    children: [
                      SupplyLineChart(
                          series: projection, demandTons: weeklyDemandRef),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Legend(
                              color: AppColors.primary, label: 'Weekly supply'),
                          const SizedBox(width: 16),
                          _Legend(
                              color: AppColors.riskHigh,
                              label: 'Demand reference'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SaturationDetailCard(result: selected),
                const SizedBox(height: 12),
                _SaturationTable(results: saturation),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CropSelector extends StatelessWidget {
  const _CropSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final crop in CropCatalog.crops)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(crop.name),
                selected: crop.id == value,
                onSelected: (_) => onChanged(crop.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

class _SaturationDetailCard extends StatelessWidget {
  const _SaturationDetailCard({required this.result});
  final SaturationResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.level) {
      _ when result.index > SaturationEngine.highFloor => AppColors.riskHigh,
      _ when result.index < SaturationEngine.lowCeiling => AppColors.riskLow,
      _ => AppColors.riskModerate,
    };
    return SectionCard(
      title: 'Market saturation index',
      icon: Icons.balance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(result.index.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supply ${Fmt.tons(result.expectedSupplyTons)} ÷ demand ${Fmt.tons(result.demandTons)}. '
                  '${result.surplusTons > 0 ? 'Projected surplus ${Fmt.tons(result.surplusTons)} — plan buy-back or alternative markets.' : 'Supply is within demand.'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RatioBar(value: result.index / 2, color: color, height: 12),
        ],
      ),
    );
  }
}

class _SaturationTable extends StatelessWidget {
  const _SaturationTable({required this.results});
  final List<SaturationResult> results;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'All crops — saturation overview',
      icon: Icons.table_rows,
      child: Column(
        children: [
          for (final r in results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(r.cropName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(Fmt.tons(r.expectedSupplyTons),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: StatusChip.saturation(r.level, dense: true),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Surfaces the contributing declarations behind a crop's supply figure so the
/// cooperative can see which members are driving the projection.
extension SupplyMembers on List<CropDeclaration> {
  List<CropDeclaration> activeForCrop(String cropId) =>
      where((d) => d.cropId == cropId && d.status.isActive).toList();
}
