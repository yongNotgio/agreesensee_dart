import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/calamity_report.dart';
import '../../models/enums.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// High-priority incident report for calamity-induced crop losses (Objective 4).
/// Captures the loss percentage and damage markers the MAO uses to verify and
/// expedite government subsidy allocation.
class CalamityFormScreen extends ConsumerStatefulWidget {
  const CalamityFormScreen({super.key});

  @override
  ConsumerState<CalamityFormScreen> createState() =>
      _CalamityFormScreenState();
}

class _CalamityFormScreenState extends ConsumerState<CalamityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _area = TextEditingController();
  final _lossValue = TextEditingController();
  final _description = TextEditingController();

  CalamityType _type = CalamityType.typhoon;
  DateTime _date = DateTime.now();
  String? _barangay;
  String? _declarationId;
  double _lossPercent = 25;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _barangay = ref.read(currentProfileProvider)?.barangay;
  }

  @override
  void dispose() {
    _area.dispose();
    _lossValue.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the barangay')));
      return;
    }
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _saving = true);

    final declarations = ref.read(declarationsProvider).valueOrNull ?? [];
    String? cropId;
    if (_declarationId != null) {
      for (final d in declarations) {
        if (d.id == _declarationId) cropId = d.cropId;
      }
    }

    final report = CalamityReport(
      id: IdGen.uuid(),
      farmerId: profile.id,
      barangay: _barangay!,
      type: _type,
      occurredOn: _date,
      affectedAreaHa: double.parse(_area.text.replaceAll(',', '')),
      lossPercent: _lossPercent,
      status: VerificationStatus.submitted,
      declarationId: _declarationId,
      cropId: cropId,
      estimatedLossValue:
          double.tryParse(_lossValue.text.replaceAll(',', '')),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      createdAt: DateTime.now(),
    );
    await ref.read(appActionsProvider).saveCalamity(report);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incident reported — submitted for verification')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final declarations = ref.watch(declarationsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report losses promptly. Accurate damage markers speed up '
                    'MAO verification for subsidy allocation.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            AppDropdown<CalamityType>(
              label: 'Calamity type',
              value: _type,
              prefixIcon: Icons.warning_amber,
              items: CalamityType.values,
              itemLabel: (t) => t.label,
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),
            AppDateField(
              label: 'Date occurred',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'Barangay',
              value: _barangay,
              prefixIcon: Icons.location_on_outlined,
              items: AppConstants.barangays,
              itemLabel: (b) => b,
              onChanged: (v) => setState(() => _barangay = v),
            ),
            const SizedBox(height: 14),
            if (declarations.isNotEmpty)
              AppDropdown<String?>(
                label: 'Affected crop (optional)',
                value: _declarationId,
                prefixIcon: Icons.eco_outlined,
                items: <String?>[null, ...declarations.map((d) => d.id)],
                itemLabel: (id) {
                  if (id == null) return 'Not linked';
                  final d = declarations.firstWhere((e) => e.id == id);
                  return '${d.cropName} • ${d.variety}';
                },
                onChanged: (v) => setState(() => _declarationId = v),
              ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Affected area (ha)',
              controller: _area,
              prefixIcon: Icons.crop_landscape,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) =>
                  Validators.positiveNumber(v, field: 'Affected area'),
            ),
            const SizedBox(height: 18),
            _LossSlider(
              value: _lossPercent,
              onChanged: (v) => setState(() => _lossPercent = v),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Estimated loss value (optional, ₱)',
              controller: _lossValue,
              prefixIcon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Description',
              controller: _description,
              hint: 'Describe the damage and circumstances',
              maxLines: 3,
              validator: (v) => Validators.required(v, field: 'Description'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LossSlider extends StatelessWidget {
  const _LossSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value >= 50
        ? AppColors.danger
        : value >= 25
            ? AppColors.warning
            : AppColors.riskModerate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Estimated crop loss',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(Fmt.percentValue(value, decimals: 0),
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: color,
          label: '${value.round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
