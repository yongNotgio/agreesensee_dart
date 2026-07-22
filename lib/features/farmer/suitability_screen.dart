import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logic/suitability_engine.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/heatmap_grid.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/suitability_card.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

/// Land suitability by barangay — what grows well *here*, before deciding what
/// to plant.
///
/// The barangay was collected on every profile, farm, and declaration and read
/// by no engine, so every farmer in Tubungan saw an identical crop ranking.
/// This is where location starts to matter.
class SuitabilityScreen extends ConsumerStatefulWidget {
  const SuitabilityScreen({super.key});

  @override
  ConsumerState<SuitabilityScreen> createState() => _SuitabilityScreenState();
}

class _SuitabilityScreenState extends ConsumerState<SuitabilityScreen> {
  String? _barangay;

  @override
  void initState() {
    super.initState();
    _barangay = ref.read(currentProfileProvider)?.barangay;
  }

  @override
  Widget build(BuildContext context) {
    final barangay = _barangay ?? AppConstants.barangays.first;
    final results = ref.watch(suitabilityForBarangayProvider(barangay));
    final matrix = ref.watch(suitabilityMatrixProvider);
    final agronomy = ref.watch(agronomyDatasetProvider);

    // No Scaffold or AppBar: this is rendered inside the Advisory tab bar, and
    // nesting a second app bar (or a second row of tabs) inside a tab reads as
    // a rendering fault rather than structure. The ranked list and the map are
    // one continuous scroll instead.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppDropdown<String>(
          label: 'Barangay',
          value: barangay,
          prefixIcon: Icons.location_on_outlined,
          items: AppConstants.barangays,
          itemLabel: (b) => b,
          onChanged: (v) {
            if (v != null) setState(() => _barangay = v);
          },
        ),
        const SizedBox(height: 14),
        const SuitabilityLegend(),
        const SizedBox(height: 16),
        Text(
          'Ranked for Brgy. $barangay',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final r in results) SuitabilityCard(result: r),
        const SizedBox(height: 8),
        _SuitabilityMap(
          matrix: matrix,
          focusBarangay: barangay,
          hasData: !agronomy.isEmpty,
        ),
      ],
    );
  }
}

class _SuitabilityMap extends StatelessWidget {
  const _SuitabilityMap({
    required this.matrix,
    required this.focusBarangay,
    required this.hasData,
  });

  final SuitabilityMatrix matrix;
  final String focusBarangay;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    if (matrix.isEmpty || !hasData) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'The barangay suitability map is not bundled in this build.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final rowIndex = matrix.barangays.indexOf(focusBarangay);

    // A Column, not a ListView: this sits inside the parent's scroll view, and
    // a nested unbounded ListView would fail its layout constraints.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Crop suitability across Tubungan',
          subtitle: 'Percent of attainable yield, by barangay',
          icon: Icons.grid_on,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeatmapGrid(
                rowLabels: matrix.barangays,
                columnLabels: [
                  for (final id in matrix.cropIds) CropCatalog.nameFor(id),
                ],
                highlightRow: rowIndex < 0 ? null : rowIndex,
                cellBuilder: (r, c) {
                  final result = matrix.at(
                    matrix.barangays[r],
                    matrix.cropIds[c],
                  );
                  if (result == null) return null;
                  return HeatmapCell(
                    value: result.yieldIndex,
                    color: suitabilityColor(result.band),
                    label: '${result.percent}',
                    tooltip:
                        '${result.cropName} in ${result.barangay}: ${result.band.label}',
                  );
                },
              ),
              const SizedBox(height: 14),
              HeatmapLegend(
                entries: [
                  for (final band in SuitabilityBand.values)
                    (label: band.label, color: suitabilityColor(band)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Values are the share of each crop\'s attainable yield actually '
          'reached in that barangay. Your barangay is highlighted and pinned '
          'to the top.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
