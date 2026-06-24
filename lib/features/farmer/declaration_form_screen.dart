import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

/// Create or edit a crop declaration. Picking a crop auto-fills the expected
/// harvest date (planting + growth duration) and a baseline expected yield
/// (catalog yield/ha × area), which the farmer can override.
class DeclarationFormScreen extends ConsumerStatefulWidget {
  const DeclarationFormScreen({super.key, this.existing});

  final CropDeclaration? existing;

  @override
  ConsumerState<DeclarationFormScreen> createState() =>
      _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends ConsumerState<DeclarationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _variety = TextEditingController();
  final _area = TextEditingController();
  final _yield = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();

  String _cropId = CropCatalog.crops.first.id;
  DateTime _plantingDate = DateTime.now();
  DateTime? _harvestDate;
  String? _barangay;
  final Set<String> _companions = {};
  bool _yieldEdited = false;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cropId = e.cropId;
      _variety.text = e.variety;
      _area.text = e.areaHa.toString();
      _yield.text = e.expectedYieldKg.toStringAsFixed(0);
      _price.text = (e.projectedPricePerKg ?? '').toString();
      _notes.text = e.notes ?? '';
      _plantingDate = e.plantingDate;
      _harvestDate = e.expectedHarvestDate;
      _barangay = e.barangay;
      _companions.addAll(e.companionCropIds);
      _yieldEdited = true;
    } else {
      _price.text = _baselinePrice(_cropId).toStringAsFixed(0);
      _recomputeDerived();
    }
  }

  /// Dataset-calibrated baseline price (PHP/kg), falling back to the catalog.
  double _baselinePrice(String cropId) =>
      ref.read(calibrationProvider)[cropId]?.baselinePricePerKg ??
      CropCatalog.byIdOrFirst(cropId).baselinePricePerKg;

  /// Dataset-calibrated mean yield (kg/ha), falling back to the catalog.
  double _baselineYieldPerHa(String cropId) =>
      ref.read(calibrationProvider)[cropId]?.meanYieldKgPerHa ??
      CropCatalog.byIdOrFirst(cropId).baselineYieldPerHa;

  @override
  void dispose() {
    _variety.dispose();
    _area.dispose();
    _yield.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Recompute harvest date and (unless edited) the baseline expected yield
  /// from the calibrated mean yield/ha.
  void _recomputeDerived() {
    final crop = CropCatalog.byIdOrFirst(_cropId);
    _harvestDate =
        _plantingDate.add(Duration(days: crop.growthDurationDays));
    final area = double.tryParse(_area.text.replaceAll(',', '')) ?? 0;
    if (!_yieldEdited && area > 0) {
      _yield.text = (_baselineYieldPerHa(_cropId) * area).toStringAsFixed(0);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null) {
      _toast('Please select a barangay');
      return;
    }
    final profile = ref.read(currentProfileProvider);
    final farm = await ref.read(primaryFarmProvider.future);
    if (profile == null) return;
    if (farm == null) {
      _toast('Set up your farm profile first (Account tab).');
      return;
    }

    setState(() => _submitting = true);
    try {
      final base = widget.existing;
      final declaration = CropDeclaration(
        id: base?.id ?? IdGen.uuid(),
        farmerId: profile.id,
        farmId: farm.id,
        cropId: _cropId,
        variety: _variety.text.trim(),
        areaHa: double.parse(_area.text.replaceAll(',', '')),
        plantingDate: _plantingDate,
        expectedHarvestDate: _harvestDate ?? _plantingDate,
        expectedYieldKg: double.parse(_yield.text.replaceAll(',', '')),
        barangay: _barangay!,
        // New declarations enter the validation chain as Pending.
        status: base?.status ?? DeclarationStatus.pending,
        companionCropIds: _companions.toList(),
        projectedPricePerKg:
            double.tryParse(_price.text.replaceAll(',', '')),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: base?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(appActionsProvider).saveDeclaration(declaration);
      if (mounted) {
        Navigator.of(context).pop();
        _toast(_isEdit ? 'Declaration updated' : 'Declaration submitted for validation');
      }
    } on Object catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final crop = CropCatalog.byIdOrFirst(_cropId);
    final companionOptions = CropCatalog.crops.where((c) => c.id != _cropId);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Edit Declaration' : 'Declare a Crop')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppDropdown<String>(
              label: 'Crop',
              value: _cropId,
              prefixIcon: Icons.eco,
              items: CropCatalog.crops.map((c) => c.id).toList(),
              itemLabel: CropCatalog.nameFor,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _cropId = v;
                  _companions.remove(v);
                  _price.text = _baselinePrice(v).toStringAsFixed(0);
                  _recomputeDerived();
                });
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Variety',
              controller: _variety,
              hint: 'e.g. Galaxy, Casino',
              prefixIcon: Icons.label_outline,
              validator: (v) => Validators.required(v, field: 'Variety'),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Area (ha)',
                    controller: _area,
                    prefixIcon: Icons.crop_landscape,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppTextField.decimal,
                    validator: (v) =>
                        Validators.positiveNumber(v, field: 'Area'),
                    onChanged: (_) => setState(_recomputeDerived),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Barangay',
                    value: _barangay,
                    prefixIcon: Icons.location_on_outlined,
                    items: AppConstants.barangays,
                    itemLabel: (b) => b,
                    onChanged: (v) => setState(() => _barangay = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppDateField(
              label: 'Planting date',
              value: _plantingDate,
              onChanged: (d) => setState(() {
                _plantingDate = d;
                _recomputeDerived();
              }),
            ),
            const SizedBox(height: 10),
            _DerivedInfo(
              harvestDate: _harvestDate,
              growthDays: crop.growthDurationDays,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Expected yield (kg)',
              controller: _yield,
              prefixIcon: Icons.scale,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) =>
                  Validators.positiveNumber(v, field: 'Expected yield'),
              onChanged: (_) => _yieldEdited = true,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Projected price (₱/kg)',
              controller: _price,
              prefixIcon: Icons.sell_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) =>
                  Validators.positiveNumber(v, field: 'Price'),
            ),
            const SizedBox(height: 18),
            _IntercropPicker(
              options: companionOptions.map((c) => c.id).toList(),
              selected: _companions,
              onToggle: (id) => setState(() {
                _companions.contains(id)
                    ? _companions.remove(id)
                    : _companions.add(id);
              }),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Notes (optional)',
              controller: _notes,
              hint: 'Anything the validators should know',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label:
                  Text(_isEdit ? 'Save Changes' : 'Submit for Validation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DerivedInfo extends StatelessWidget {
  const _DerivedInfo({required this.harvestDate, required this.growthDays});
  final DateTime? harvestDate;
  final int growthDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, size: 18, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Expected harvest ${Fmt.date(harvestDate)} '
              '(~$growthDays-day cycle)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select chips for intercropping companions (mix-and-match strategy).
class _IntercropPicker extends StatelessWidget {
  const _IntercropPicker({
    required this.options,
    required this.selected,
    required this.onToggle,
  });
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intercropping companions (optional)',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text('Mix-and-match crops planted alongside to spread market risk.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final id in options)
              FilterChip(
                label: Text(CropCatalog.nameFor(id)),
                selected: selected.contains(id),
                onSelected: (_) => onToggle(id),
              ),
          ],
        ),
      ],
    );
  }
}
