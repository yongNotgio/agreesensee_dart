import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/production_report.dart';
import '../../providers/app_actions.dart';

/// Opens the modal sheet to record post-harvest results for a declaration,
/// which marks it harvested and unlocks the realized P&L.
Future<void> showProductionReportSheet(
  BuildContext context,
  WidgetRef ref,
  CropDeclaration declaration,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductionReportSheet(declaration: declaration),
  );
}

class _ProductionReportSheet extends ConsumerStatefulWidget {
  const _ProductionReportSheet({required this.declaration});
  final CropDeclaration declaration;

  @override
  ConsumerState<_ProductionReportSheet> createState() =>
      _ProductionReportSheetState();
}

class _ProductionReportSheetState
    extends ConsumerState<_ProductionReportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _yield;
  late final TextEditingController _price;
  final _loss = TextEditingController(text: '0');
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the declaration's projections as a starting point.
    _yield = TextEditingController(
        text: widget.declaration.expectedYieldKg.toStringAsFixed(0));
    _price = TextEditingController(
        text: widget.declaration.effectivePricePerKg.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _yield.dispose();
    _price.dispose();
    _loss.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final d = widget.declaration;
    final report = ProductionReport(
      id: IdGen.uuid(),
      declarationId: d.id,
      farmerId: d.farmerId,
      actualYieldKg: double.parse(_yield.text.replaceAll(',', '')),
      actualPricePerKg: double.parse(_price.text.replaceAll(',', '')),
      harvestedOn: _date,
      lossKg: double.tryParse(_loss.text.replaceAll(',', '')) ?? 0,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: DateTime.now(),
    );
    final actions = ref.read(appActionsProvider);
    await actions.saveProductionReport(report);
    // Mark the declaration as harvested.
    await actions
        .saveDeclaration(d.copyWith(status: DeclarationStatus.harvested));
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
            Text('Record harvest results',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Actual yield (kg)',
              controller: _yield,
              prefixIcon: Icons.scale,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) => Validators.positiveNumber(v, field: 'Yield'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Actual selling price (₱/kg)',
              controller: _price,
              prefixIcon: Icons.sell_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) => Validators.positiveNumber(v, field: 'Price'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Loss / rejects (kg)',
              controller: _loss,
              prefixIcon: Icons.remove_circle_outline,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) =>
                  Validators.nonNegativeNumber(v, field: 'Loss'),
            ),
            const SizedBox(height: 12),
            AppDateField(
              label: 'Harvest date',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Notes (optional)',
              controller: _notes,
              maxLines: 2,
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
              label: const Text('Save & compute P&L'),
            ),
          ],
        ),
      ),
    );
  }
}
