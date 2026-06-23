import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';

/// Opens the modal sheet to add an expense to a declaration's P&L ledger.
Future<void> showExpenseSheet(
  BuildContext context,
  WidgetRef ref,
  String declarationId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExpenseSheet(declarationId: declarationId),
  );
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({required this.declarationId});
  final String declarationId;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.fertilizer;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _saving = true);
    final expense = Expense(
      id: IdGen.uuid(),
      declarationId: widget.declarationId,
      farmerId: profile.id,
      category: _category,
      description: _description.text.trim(),
      amount: double.parse(_amount.text.replaceAll(',', '')),
      incurredOn: _date,
      createdAt: DateTime.now(),
    );
    await ref.read(appActionsProvider).saveExpense(expense);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add expense',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppDropdown<ExpenseCategory>(
              label: 'Category',
              value: _category,
              items: ExpenseCategory.values,
              itemLabel: (c) => c.label,
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Description',
              controller: _description,
              hint: 'e.g. Complete 14-14-14 (4 bags)',
              validator: (v) => Validators.required(v, field: 'Description'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Amount (₱)',
              controller: _amount,
              prefixIcon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) => Validators.positiveNumber(v, field: 'Amount'),
            ),
            const SizedBox(height: 12),
            AppDateField(
              label: 'Date incurred',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text('Save • ${_amount.text.isEmpty ? '₱0' : Fmt.peso(double.tryParse(_amount.text.replaceAll(',', '')) ?? 0)}'),
            ),
          ],
        ),
      ),
    );
  }
}
