import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/calamity_report.dart';
import '../../models/logbook_entry.dart';
import '../../providers/app_actions.dart';
import '../../providers/data_providers.dart';
import 'calamity_form_screen.dart';
import 'logbook_form_screen.dart';

/// Records hub: the agronomic logbook and the calamity/incident reports —
/// study Objective 4 (digital logbook + incident reporting).
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Records'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Logbook'),
            Tab(text: 'Incidents'),
          ]),
        ),
        body: const TabBarView(
          children: [_LogbookTab(), _CalamityTab()],
        ),
      ),
    );
  }
}

// ── Logbook ──────────────────────────────────────────────────────────────────

class _LogbookTab extends ConsumerWidget {
  const _LogbookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logbookProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'log-fab',
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LogbookFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Log activity'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(logbookProvider),
        child: AsyncValueView(
          value: logs,
          onRetry: () => ref.invalidate(logbookProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.menu_book,
                  title: 'No logbook entries',
                  message:
                      'Record agronomic events like fertilizer application, '
                      'irrigation, and pest control.',
                  actionLabel: 'Log first activity',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LogbookFormScreen())),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              itemBuilder: (_, i) => _LogTile(entry: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.entry});
  final LogbookEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) =>
            ref.read(appActionsProvider).deleteLogEntry(entry.id),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
            child: Icon(entry.activity.icon, color: AppColors.secondary),
          ),
          title: Text(entry.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.activity.label} • ${Fmt.date(entry.performedOn)}'),
              if (entry.inputUsed != null)
                Text(
                  '${entry.inputUsed}'
                  '${entry.quantity != null ? ' — ${Fmt.number(entry.quantity!)} ${entry.unit ?? ''}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          trailing: entry.cost != null
              ? Text(Fmt.pesoCompact(entry.cost!),
                  style: const TextStyle(fontWeight: FontWeight.w700))
              : null,
          isThreeLine: entry.inputUsed != null,
        ),
      ),
    );
  }
}

// ── Calamity / incidents ─────────────────────────────────────────────────────

class _CalamityTab extends ConsumerWidget {
  const _CalamityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(calamityProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cal-fab',
        backgroundColor: AppColors.danger,
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalamityFormScreen())),
        icon: const Icon(Icons.report),
        label: const Text('Report incident'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(calamityProvider),
        child: AsyncValueView(
          value: reports,
          onRetry: () => ref.invalidate(calamityProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.health_and_safety,
                  title: 'No incidents reported',
                  message:
                      'Report calamity-induced crop losses to fast-track '
                      'verification for government subsidies.',
                  actionLabel: 'Report an incident',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CalamityFormScreen())),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              itemBuilder: (_, i) => _CalamityCard(report: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CalamityCard extends StatelessWidget {
  const _CalamityCard({required this.report});
  final CalamityReport report;

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
                CircleAvatar(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                  child: Icon(report.type.icon, color: AppColors.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.type.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                          '${report.barangay} • ${Fmt.date(report.occurredOn)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusChip.verification(report.status, dense: true),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LossMeter(percent: report.lossPercent),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Affected area',
                        style: theme.textTheme.labelSmall),
                    Text(Fmt.area(report.affectedAreaHa),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (report.estimatedLossValue != null) ...[
                      const SizedBox(height: 4),
                      Text('Est. loss',
                          style: theme.textTheme.labelSmall),
                      Text(Fmt.pesoCompact(report.estimatedLossValue!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger)),
                    ],
                  ],
                ),
              ],
            ),
            if (report.description != null) ...[
              const SizedBox(height: 10),
              Text(report.description!,
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _LossMeter extends StatelessWidget {
  const _LossMeter({required this.percent});
  final double percent;
  @override
  Widget build(BuildContext context) {
    final color = percent >= 50
        ? AppColors.danger
        : percent >= 25
            ? AppColors.warning
            : AppColors.riskModerate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Crop loss',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Row(children: [
          Text('${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: color)),
        ]),
        const SizedBox(height: 4),
        RatioBar(value: percent / 100, color: color, height: 8),
      ],
    );
  }
}
