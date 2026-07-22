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
import '../../core/widgets/heatmap_grid.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
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
            // Demand comes from the resolved figure (cooperative-declared
            // where available, else the monthly baseline) so this screen
            // and the farmer's warnings never disagree.
            final saturation =
                ref.watch(saturationProvider).valueOrNull ?? const [];
            final selected = saturation.isEmpty
                ? SaturationEngine.forCrop(
                    cropId: _cropId, declarations: declarations)
                : saturation.firstWhere(
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
                const SizedBox(height: 12),
                const _MonthlyHeatmap(),
                const SizedBox(height: 12),
                const _BarangayHeatmap(),
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

/// Colour for a saturation band — shared by the table and both heat maps.
Color _saturationColor(SaturationLevel level) => switch (level) {
      SaturationLevel.low => AppColors.riskLow,
      SaturationLevel.moderate => AppColors.riskModerate,
      SaturationLevel.high => AppColors.riskHigh,
    };

/// The full saturation picture as a real table.
///
/// This used to be a row list showing only a crop name, a tonnage, and a
/// coloured chip — the index itself, the demand it was divided by, and where
/// that demand came from were all invisible, which made the number impossible
/// to check. All of it is now on screen, sortable.
class _SaturationTable extends StatefulWidget {
  const _SaturationTable({required this.results});
  final List<SaturationResult> results;

  @override
  State<_SaturationTable> createState() => _SaturationTableState();
}

class _SaturationTableState extends State<_SaturationTable> {
  int _sortColumn = 3; // index
  bool _ascending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [...widget.results];
    rows.sort((a, b) {
      final cmp = switch (_sortColumn) {
        0 => a.cropName.compareTo(b.cropName),
        1 => a.expectedSupplyTons.compareTo(b.expectedSupplyTons),
        2 => a.demandTons.compareTo(b.demandTons),
        4 => a.contributingDeclarations.compareTo(b.contributingDeclarations),
        _ => a.index.compareTo(b.index),
      };
      return _ascending ? cmp : -cmp;
    });

    void onSort(int column, bool ascending) => setState(() {
          _sortColumn = column;
          _ascending = ascending;
        });

    return SectionCard(
      title: 'All crops — saturation overview',
      subtitle: 'Supply ÷ demand, by crop',
      icon: Icons.table_rows,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumn,
          sortAscending: _ascending,
          headingRowHeight: 40,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 52,
          columnSpacing: 22,
          columns: [
            DataColumn(label: const Text('Crop'), onSort: onSort),
            DataColumn(
                label: const Text('Supply'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('Demand'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('Index'), numeric: true, onSort: onSort),
            DataColumn(
                label: const Text('Farms'), numeric: true, onSort: onSort),
            const DataColumn(label: Text('Risk')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.cropName,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(Fmt.tons(r.expectedSupplyTons))),
                DataCell(
                  Tooltip(
                    message: r.demand.provenance,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Fmt.tons(r.demandTons)),
                        const SizedBox(width: 4),
                        Icon(
                          r.demandSource == DemandSource.cooperative
                              ? Icons.verified_user
                              : Icons.public,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(
                  r.index.toStringAsFixed(2),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _saturationColor(r.level)),
                )),
                DataCell(Text('${r.contributingDeclarations}')),
                DataCell(StatusChip.saturation(r.level, dense: true)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Crop × month saturation — where a glut is building, and when.
///
/// A single index for "right now" hides the shape of the problem: five farmers
/// harvesting in the same week is a very different situation from the same
/// tonnage spread over a quarter.
class _MonthlyHeatmap extends ConsumerWidget {
  const _MonthlyHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixAsync = ref.watch(saturationMatrixProvider);

    return matrixAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (matrix) {
        if (matrix.isEmpty) return const SizedBox.shrink();
        return SectionCard(
          title: 'Saturation by month',
          subtitle: 'Projected supply ÷ demand over the next 12 months',
          icon: Icons.calendar_view_month,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeatmapGrid(
                rowLabels: [
                  for (final id in matrix.cropIds) CropCatalog.nameFor(id)
                ],
                columnLabels: [
                  for (final m in matrix.months) Fmt.monthShort(m)
                ],
                cellWidth: 50,
                cellBuilder: (r, c) {
                  final cell =
                      matrix.at(matrix.cropIds[r], matrix.months[c]);
                  if (cell == null) return null;
                  return HeatmapCell(
                    value: cell.index,
                    color: cell.supplyTons <= 0
                        ? Colors.blueGrey
                        : _saturationColor(cell.level),
                    label: cell.supplyTons <= 0
                        ? '—'
                        : cell.index.toStringAsFixed(1),
                    tooltip: '${CropCatalog.nameFor(cell.cropId)} '
                        '${Fmt.monthShort(DateTime(cell.year, cell.month))}: '
                        '${Fmt.tons(cell.supplyTons)} supply vs '
                        '${Fmt.tons(cell.demandTons)} demand',
                  );
                },
              ),
              const SizedBox(height: 12),
              HeatmapLegend(entries: [
                for (final l in SaturationLevel.values)
                  (label: l.label, color: _saturationColor(l)),
                (label: 'No supply', color: Colors.blueGrey),
              ]),
            ],
          ),
        );
      },
    );
  }
}

/// Crop × barangay planted volume — where planting is concentrated.
///
/// The barangay was recorded on every declaration and never analysed. This is
/// the first view that answers "who is planting what, where".
class _BarangayHeatmap extends ConsumerWidget {
  const _BarangayHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplyAsync = ref.watch(supplyByBarangayProvider);

    return supplyAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (byBarangay) {
        if (byBarangay.isEmpty) return const SizedBox.shrink();

        final barangays = byBarangay.keys.toList()..sort();
        final cropIds = CropCatalog.crops.map((c) => c.id).toList();

        // Scale colour intensity against the single heaviest concentration.
        var peak = 0.0;
        for (final row in byBarangay.values) {
          for (final v in row.values) {
            if (v > peak) peak = v;
          }
        }

        return SectionCard(
          title: 'Planting concentration',
          subtitle: 'Expected supply (tons) by barangay',
          icon: Icons.map_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeatmapGrid(
                rowLabels: barangays,
                columnLabels: [
                  for (final id in cropIds) CropCatalog.nameFor(id)
                ],
                cellBuilder: (r, c) {
                  final tons = byBarangay[barangays[r]]?[cropIds[c]] ?? 0;
                  if (tons <= 0) return null;
                  final share = peak <= 0 ? 0.0 : tons / peak;
                  return HeatmapCell(
                    value: tons,
                    color: share > 0.66
                        ? AppColors.riskHigh
                        : share > 0.33
                            ? AppColors.riskModerate
                            : AppColors.riskLow,
                    label: Fmt.number(tons),
                    tooltip: '${CropCatalog.nameFor(cropIds[c])} in '
                        '${barangays[r]}: ${Fmt.tons(tons)} expected',
                  );
                },
              ),
              const SizedBox(height: 12),
              HeatmapLegend(entries: [
                (label: 'Light', color: AppColors.riskLow),
                (label: 'Moderate', color: AppColors.riskModerate),
                (label: 'Heavy', color: AppColors.riskHigh),
              ]),
            ],
          ),
        );
      },
    );
  }
}

/// Surfaces the contributing declarations behind a crop's supply figure so the
/// cooperative can see which members are driving the projection.
extension SupplyMembers on List<CropDeclaration> {
  List<CropDeclaration> activeForCrop(String cropId) =>
      where((d) => d.cropId == cropId && d.status.isActive).toList();
}
