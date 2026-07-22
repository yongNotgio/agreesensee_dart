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
  final _buyer = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  SalesChannel _channel = SalesChannel.bagsakan;
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
    _buyer.dispose();
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
      soldToChannel: _channel,
      buyerName: _buyer.text.trim().isEmpty ? null : _buyer.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: DateTime.now(),
    );
    final actions = ref.read(appActionsProvider);
    await actions.saveProductionReport(report);
    // Mark the declaration as harvested. Nothing is left to schedule for a
    // finished crop, so skip regenerating its calendar entirely.
    await actions.saveDeclaration(
      d.copyWith(status: DeclarationStatus.harvested),
      regenerateCalendar: false,
    );
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

            // Where the harvest went. Without this the municipality can see
            // what was planted but not where the supply ended up — the gap
            // behind "ay diin nagkadto ang supply?".
            AppDropdown<SalesChannel>(
              label: 'Where did you sell it?',
              value: _channel,
              prefixIcon: Icons.local_shipping_outlined,
              items: SalesChannel.values,
              itemLabel: (c) => c.label,
              onChanged: (c) => setState(() => _channel = c ?? _channel),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Buyer name (optional)',
              controller: _buyer,
              prefixIcon: Icons.person_outline,
              hint: 'Trader, cooperative, or business name',
            ),
            if (_channel.leavesMunicipality) ...[
              const SizedBox(height: 8),
              const _LeakageNotice(),
            ],
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

/// Shown when produce leaves the municipality's monitored supply chain, so the
/// farmer understands why the app asks and that the answer is not a judgement.
class _LeakageNotice extends StatelessWidget {
  const _LeakageNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_outlined,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording this helps the municipality understand why local '
              'supply sometimes falls short even in a good harvest. Selling '
              'outside Tubungan is your decision — this is only tracking.',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
