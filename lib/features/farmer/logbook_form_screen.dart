import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/logbook_entry.dart';
import '../../models/planned_activity.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// Record a farm activity — and the cost it incurred, in the same entry.
///
/// These used to be two separate forms, and a cost typed into the logbook never
/// reached the P&L at all: the financial engine only ever summed `Expense`
/// rows. A farmer either entered the same figure twice or their ROI was quietly
/// wrong. Now one save writes both records, linked in both directions.
///
/// Opening this from a scheduled crop-calendar operation pre-fills the activity
/// type, title, and suggested input, so confirming what the system recommended
/// is a couple of taps.
class LogbookFormScreen extends ConsumerStatefulWidget {
  const LogbookFormScreen({super.key, this.planned});

  /// The scheduled operation being fulfilled, when opened from the calendar.
  final PlannedActivity? planned;

  @override
  ConsumerState<LogbookFormScreen> createState() => _LogbookFormScreenState();
}

class _LogbookFormScreenState extends ConsumerState<LogbookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _input = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  final _cost = TextEditingController();

  ActivityType _activity = ActivityType.fertilizing;
  ExpenseCategory _category = ExpenseCategory.fertilizer;
  DateTime _date = DateTime.now();
  String? _declarationId;

  /// Whether the cost block is expanded. Costs are common but not universal, so
  /// the fields stay out of the way until asked for.
  bool _hasCost = false;
  bool _saving = false;

  bool get _fromPlan => widget.planned != null;

  @override
  void initState() {
    super.initState();
    final p = widget.planned;
    if (p != null) {
      _activity = p.activity;
      _category = p.activity.defaultExpenseCategory;
      _title.text = p.title;
      _declarationId = p.declarationId;
      _input.text = p.suggestedInput ?? '';
      _unit.text = p.unit ?? '';
      _date = p.scheduledOn.isAfter(DateTime.now()) ? DateTime.now() : p.scheduledOn;
    } else {
      _category = _activity.defaultExpenseCategory;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _input.dispose();
    _quantity.dispose();
    _unit.dispose();
    _cost.dispose();
    super.dispose();
  }

  double get _costValue => double.tryParse(_cost.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // An expense with no declaration cannot be attributed to any P&L, so this
    // is refused loudly rather than dropped silently.
    if (_hasCost && _declarationId == null) {
      _toast('Link this activity to a crop so the cost reaches its P&L.');
      return;
    }

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _saving = true);

    final entryId = IdGen.uuid();
    final entry = LogbookEntry(
      id: entryId,
      farmerId: profile.id,
      activity: _activity,
      title: _title.text.trim(),
      performedOn: _date,
      declarationId: _declarationId,
      details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      inputUsed: _input.text.trim().isEmpty ? null : _input.text.trim(),
      quantity: double.tryParse(_quantity.text.replaceAll(',', '')),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      cost: _hasCost ? _costValue : null,
      createdAt: DateTime.now(),
    );

    final expense = !_hasCost || _costValue <= 0
        ? null
        : Expense(
            id: IdGen.uuid(),
            declarationId: _declarationId!,
            farmerId: profile.id,
            category: _category,
            description: _title.text.trim(),
            amount: _costValue,
            incurredOn: _date,
            logbookEntryId: entryId,
            createdAt: DateTime.now(),
          );

    try {
      final actions = ref.read(appActionsProvider);
      if (_fromPlan) {
        await actions.completePlannedActivity(
          planned: widget.planned!,
          entry: entry,
          expense: expense,
        );
      } else {
        await actions.saveActivityWithCost(entry, expense: expense);
      }
      if (mounted) {
        Navigator.of(context).pop();
        _toast(expense == null
            ? 'Activity logged'
            : 'Activity logged • ${Fmt.peso(expense.amount)} added to your P&L');
      }
    } on Object catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final declarations = ref.watch(declarationsProvider).valueOrNull ?? [];
    final active = declarations.where((d) => d.status.isActive).toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(_fromPlan ? 'Confirm Activity' : 'Log Activity')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_fromPlan) ...[
              _ScheduledBanner(planned: widget.planned!),
              const SizedBox(height: 14),
            ],
            AppDropdown<ActivityType>(
              label: 'Activity type',
              value: _activity,
              prefixIcon: Icons.category_outlined,
              items: ActivityType.values,
              itemLabel: (a) => a.label,
              onChanged: (v) => setState(() {
                _activity = v ?? _activity;
                // Keep the expense category in step unless the farmer has
                // deliberately changed it.
                _category = _activity.defaultExpenseCategory;
              }),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'What did you do?',
              controller: _title,
              hint: 'e.g. Basal fertilizer application',
              validator: (v) => Validators.required(v, field: 'Title'),
            ),
            const SizedBox(height: 14),
            AppDateField(
              label: 'Date performed',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 14),
            if (active.isNotEmpty)
              AppDropdown<String?>(
                label: _hasCost ? 'Crop (required for costs)' : 'Crop (optional)',
                value: _declarationId,
                prefixIcon: Icons.eco_outlined,
                items: <String?>[null, ...active.map((d) => d.id)],
                itemLabel: (id) =>
                    id == null ? 'Not linked' : _labelFor(active, id),
                onChanged: (v) => setState(() => _declarationId = v),
              ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Input used (optional)',
              controller: _input,
              hint: 'e.g. Complete 14-14-14, Cypermethrin',
              prefixIcon: Icons.science_outlined,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Quantity',
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppTextField.decimal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Unit',
                    controller: _unit,
                    hint: 'kg, L, bags',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CostBlock(
              expanded: _hasCost,
              controller: _cost,
              category: _category,
              onToggle: () => setState(() => _hasCost = !_hasCost),
              onCategoryChanged: (c) => setState(() => _category = c),
              onAmountChanged: () => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Notes (optional)',
              controller: _details,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_hasCost && _costValue > 0
                  ? 'Save activity + ${Fmt.peso(_costValue)}'
                  : 'Save activity'),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(List<CropDeclaration> declarations, String id) {
    final d = declarations.firstWhere((e) => e.id == id);
    return '${d.cropName} • ${d.variety}';
  }
}

/// Collapsed cost capture — one tap to open, pre-categorised by activity type.
class _CostBlock extends StatelessWidget {
  const _CostBlock({
    required this.expanded,
    required this.controller,
    required this.category,
    required this.onToggle,
    required this.onCategoryChanged,
    required this.onAmountChanged,
  });

  final bool expanded;
  final TextEditingController controller;
  final ExpenseCategory category;
  final VoidCallback onToggle;
  final ValueChanged<ExpenseCategory> onCategoryChanged;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!expanded) {
      return OutlinedButton.icon(
        onPressed: onToggle,
        icon: const Icon(Icons.add),
        label: const Text('Add cost incurred'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cost incurred',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: onToggle,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove cost',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            label: 'Amount (₱)',
            controller: controller,
            prefixIcon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: AppTextField.decimal,
            validator: (v) => Validators.positiveNumber(v, field: 'Amount'),
            onChanged: (_) => onAmountChanged(),
          ),
          const SizedBox(height: 12),
          AppDropdown<ExpenseCategory>(
            label: 'Expense category',
            value: category,
            items: ExpenseCategory.values,
            itemLabel: (c) => c.label,
            onChanged: (c) => onCategoryChanged(c ?? category),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'This posts to the linked crop\'s profit & loss — no need to '
                  'record it again as a separate expense.',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Context banner when confirming a system-scheduled operation.
class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({required this.planned});
  final PlannedActivity planned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = planned.isOverdue();
    final color = overdue ? AppColors.warning : AppColors.info;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(overdue ? Icons.schedule : Icons.event_available,
              size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overdue
                      ? 'Was scheduled for ${Fmt.date(planned.scheduledOn)}'
                      : 'Scheduled for ${Fmt.date(planned.scheduledOn)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (planned.suggestedInput != null)
                  Text('Recommended: ${planned.suggestedInput}',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
