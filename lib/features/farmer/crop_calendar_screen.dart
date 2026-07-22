import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/crop_calendar_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/section_card.dart';
import '../../models/crop_declaration.dart';
import '../../models/planned_activity.dart';
import '../../providers/app_actions.dart';
import '../../providers/data_providers.dart';
import 'logbook_form_screen.dart';

/// The farmer's crop calendar: what the system says to do, and when.
///
/// The logbook only ever recorded the past. The crop and planting date are
/// already known, so the schedule of fertiliser splits, irrigation intervals,
/// and spray windows can be derived and put in front of the farmer instead of
/// waiting to be told after the fact. Confirming an item logs it — and captures
/// the cost in the same step.
class CropCalendarScreen extends ConsumerStatefulWidget {
  const CropCalendarScreen({super.key, this.embedded = false});

  /// True when rendered inside another screen's tab bar, where supplying a
  /// second [Scaffold]/[AppBar] would stack a duplicate header on screen.
  final bool embedded;

  @override
  ConsumerState<CropCalendarScreen> createState() => _CropCalendarScreenState();
}

class _CropCalendarScreenState extends ConsumerState<CropCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(plannedActivitiesProvider);
    final declarations = ref.watch(declarationsProvider).valueOrNull ?? [];

    final body = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(plannedActivitiesProvider);
        ref.invalidate(declarationsProvider);
      },
      child: AsyncValueView(
        value: activitiesAsync,
        onRetry: () => ref.invalidate(plannedActivitiesProvider),
        data: (all) {
          if (all.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.event_note,
                  title: 'No schedule yet',
                  message:
                      'Declare a crop and AgriSense builds the full activity '
                      'calendar for it — when to fertilise, irrigate, spray, '
                      'and harvest.',
                ),
              ],
            );
          }

          final pending = all.where((a) => a.isPending).toList();
          final overdue = pending.where((a) => a.isOverdue()).toList();
          final byDay = CropCalendarEngine.groupByDay(pending);
          final selected = _selectedDay;
          final agenda = selected == null
              ? _upcoming(pending)
              : (byDay[_dayOf(selected)] ?? const <PlannedActivity>[]);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (overdue.isNotEmpty) ...[
                _OverdueBanner(count: overdue.length),
                const SizedBox(height: 12),
              ],
              _MonthGrid(
                month: _month,
                byDay: byDay,
                selectedDay: selected,
                onMonthChanged: (m) => setState(() {
                  _month = m;
                  _selectedDay = null;
                }),
                onDaySelected: (d) => setState(() {
                  _selectedDay =
                      _selectedDay != null && _dayOf(_selectedDay!) == _dayOf(d)
                      ? null
                      : d;
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selected == null
                          ? 'Next 14 days'
                          : 'On ${Fmt.date(selected)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedDay = null),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (agenda.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    selected == null
                        ? 'Nothing scheduled in the next two weeks.'
                        : 'Nothing scheduled on this day.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                for (final a in agenda)
                  _ActivityTile(
                    activity: a,
                    declaration: _declarationFor(declarations, a),
                  ),
            ],
          );
        },
      ),
    );

    // Embedded, the Scaffold carries no app bar — the host screen supplies it —
    // but it still provides the Material surface and background the tab body is
    // painted on, matching _LogbookTab and _CalamityTab.
    if (widget.embedded) return Scaffold(body: body);
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Calendar')),
      body: body,
    );
  }

  List<PlannedActivity> _upcoming(List<PlannedActivity> pending) {
    final today = _dayOf(DateTime.now());
    final horizon = today.add(const Duration(days: 14));
    return pending
        .where((a) => !_dayOf(a.scheduledOn).isAfter(horizon))
        .toList()
      ..sort((a, b) => a.scheduledOn.compareTo(b.scheduledOn));
  }

  CropDeclaration? _declarationFor(
    List<CropDeclaration> declarations,
    PlannedActivity a,
  ) {
    for (final d in declarations) {
      if (d.id == a.declarationId) return d;
    }
    return null;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count scheduled ${count == 1 ? 'activity is' : 'activities are'} '
              'past due. Confirm what you did, or skip what you no longer need.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Month grid with a dot per scheduled day.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime month;
  final Map<DateTime, List<PlannedActivity>> byDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid.
    final leadingBlanks = (first.weekday - DateTime.monday) % 7;
    final today = DateTime.now();

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  Fmt.monthYear(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = DateTime(
                month.year,
                month.month,
                i - leadingBlanks + 1,
              );
              final items = byDay[day] ?? const <PlannedActivity>[];
              final isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final isSelected =
                  selectedDay != null &&
                  selectedDay!.year == day.year &&
                  selectedDay!.month == day.month &&
                  selectedDay!.day == day.day;
              final hasOverdue = items.any((a) => a.isOverdue());

              return InkWell(
                onTap: items.isEmpty ? null : () => onDaySelected(day),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (items.isNotEmpty)
                        Container(
                          width: items.length > 2 ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : hasOverdue
                                ? AppColors.warning
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One scheduled operation, with confirm / skip actions.
class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.activity, required this.declaration});

  final PlannedActivity activity;
  final CropDeclaration? declaration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overdue = activity.isOverdue();
    final color = overdue ? AppColors.warning : AppColors.primary;
    final qty = declaration == null
        ? null
        : activity.quantityFor(declaration!.areaHa);

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
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(activity.activity.icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          Fmt.dateShort(activity.scheduledOn),
                          if (declaration != null)
                            '${declaration!.cropName} • ${declaration!.variety}',
                        ].join(' • '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (overdue)
                  const Icon(
                    Icons.priority_high,
                    size: 18,
                    color: AppColors.warning,
                  ),
              ],
            ),
            if (activity.suggestedInput != null || qty != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          if (activity.suggestedInput != null)
                            activity.suggestedInput!,
                          if (qty != null && qty > 0)
                            '≈ ${Fmt.number(qty)} ${activity.unit ?? ''}'
                                .trim(),
                        ].join(' — '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Both buttons take a flex slot. The button themes set
            // `minimumSize: Size.fromHeight(52)` — an *infinite* minimum width
            // — which is fine wherever the incoming maxWidth is finite, but a
            // non-flex Row child is laid out with unbounded width. That made
            // the Skip button assert during performLayout, and a layout that
            // throws paints nothing: the whole Calendar tab came up blank.
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LogbookFormScreen(planned: activity),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('I did this'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(appActionsProvider)
                        .skipPlannedActivity(activity),
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
