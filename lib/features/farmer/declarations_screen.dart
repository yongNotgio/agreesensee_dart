import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/crop_declaration.dart';
import '../../providers/data_providers.dart';
import 'declaration_detail_screen.dart';
import 'declaration_form_screen.dart';

/// Lists the farmer's crop declarations (Phase 2 of the workflow), grouped by
/// active vs. closed, each showing its validation status.
class DeclarationsScreen extends ConsumerWidget {
  const DeclarationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final declarations = ref.watch(declarationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Crops')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeclarationFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Declare'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(declarationsProvider),
        child: AsyncValueView(
          value: declarations,
          onRetry: () => ref.invalidate(declarationsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.eco,
                  title: 'No declarations yet',
                  message:
                      'Declare a crop to start planning and validation.',
                  actionLabel: 'Declare crop',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DeclarationFormScreen())),
                ),
              ]);
            }
            final active = list.where((d) => d.status.isActive).toList();
            final closed = list.where((d) => !d.status.isActive).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader('Active (${active.length})'),
                  for (final d in active) _DeclarationCard(declaration: d),
                ],
                if (closed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionHeader('Closed (${closed.length})'),
                  for (final d in closed) _DeclarationCard(declaration: d),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _DeclarationCard extends StatelessWidget {
  const _DeclarationCard({required this.declaration});
  final CropDeclaration declaration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                DeclarationDetailScreen(declarationId: declaration.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.spa, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${declaration.cropName} • ${declaration.variety}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                            '${declaration.barangay} • ${Fmt.area(declaration.areaHa)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  StatusChip.declaration(declaration.status, dense: true),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _MiniStat(
                    icon: Icons.event_available,
                    label: 'Harvest',
                    value: Fmt.dateShort(declaration.expectedHarvestDate),
                  ),
                  _MiniStat(
                    icon: Icons.scale,
                    label: 'Yield',
                    value: Fmt.weightKg(declaration.expectedYieldKg),
                  ),
                  _MiniStat(
                    icon: Icons.payments,
                    label: 'Revenue',
                    value: Fmt.pesoCompact(declaration.projectedRevenue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
