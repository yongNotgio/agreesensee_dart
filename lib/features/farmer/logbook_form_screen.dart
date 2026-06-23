import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/logbook_entry.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// Records a single agronomic logbook entry (Objective 4).
class LogbookFormScreen extends ConsumerStatefulWidget {
  const LogbookFormScreen({super.key});

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
  DateTime _date = DateTime.now();
  String? _declarationId;
  bool _saving = false;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _saving = true);
    final entry = LogbookEntry(
      id: IdGen.uuid(),
      farmerId: profile.id,
      activity: _activity,
      title: _title.text.trim(),
      performedOn: _date,
      declarationId: _declarationId,
      details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      inputUsed: _input.text.trim().isEmpty ? null : _input.text.trim(),
      quantity: double.tryParse(_quantity.text.replaceAll(',', '')),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      cost: double.tryParse(_cost.text.replaceAll(',', '')),
      createdAt: DateTime.now(),
    );
    await ref.read(appActionsProvider).saveLogEntry(entry);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final declarations = ref.watch(declarationsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Log Activity')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppDropdown<ActivityType>(
              label: 'Activity type',
              value: _activity,
              prefixIcon: Icons.category_outlined,
              items: ActivityType.values,
              itemLabel: (a) => a.label,
              onChanged: (v) => setState(() => _activity = v ?? _activity),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Title',
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
            if (declarations.isNotEmpty)
              AppDropdown<String?>(
                label: 'Linked crop (optional)',
                value: _declarationId,
                prefixIcon: Icons.eco_outlined,
                items: <String?>[null, ...declarations.map((d) => d.id)],
                itemLabel: (id) => id == null
                    ? 'Not linked'
                    : _labelFor(declarations, id),
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
            const SizedBox(height: 14),
            AppTextField(
              label: 'Cost (optional, ₱)',
              controller: _cost,
              prefixIcon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Details (optional)',
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
              label: const Text('Save entry'),
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
