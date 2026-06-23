import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/farm.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';

/// Farm profiling form (Phase 1). Creates or edits the farmer's farm parcel.
class FarmFormScreen extends ConsumerStatefulWidget {
  const FarmFormScreen({super.key, this.existing});
  final Farm? existing;

  @override
  ConsumerState<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends ConsumerState<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _soil = TextEditingController();
  final _activities = TextEditingController();

  String? _barangay;
  final Set<String> _previousCrops = {};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _area.text = e.totalAreaHa.toString();
      _soil.text = e.soilType ?? '';
      _activities.text = e.previousActivities ?? '';
      _barangay = e.barangay;
      _previousCrops.addAll(e.previousCrops);
    } else {
      _barangay = ref.read(currentProfileProvider)?.barangay;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _soil.dispose();
    _activities.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a barangay')));
      return;
    }
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _saving = true);
    final base = widget.existing;
    final farm = Farm(
      id: base?.id ?? IdGen.uuid(),
      ownerId: profile.id,
      name: _name.text.trim(),
      barangay: _barangay!,
      totalAreaHa: double.parse(_area.text.replaceAll(',', '')),
      soilType: _soil.text.trim().isEmpty ? null : _soil.text.trim(),
      previousCrops: _previousCrops.toList(),
      previousActivities:
          _activities.text.trim().isEmpty ? null : _activities.text.trim(),
      latitude: base?.latitude,
      longitude: base?.longitude,
      photoUrls: base?.photoUrls ?? const [],
      createdAt: base?.createdAt ?? DateTime.now(),
    );
    await ref.read(appActionsProvider).saveFarm(farm);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Farm' : 'Set Up Farm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              label: 'Farm name',
              controller: _name,
              prefixIcon: Icons.home_work_outlined,
              hint: 'e.g. Dela Cruz Family Farm',
              validator: (v) => Validators.required(v, field: 'Farm name'),
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
            AppTextField(
              label: 'Total area (ha)',
              controller: _area,
              prefixIcon: Icons.crop_landscape,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppTextField.decimal,
              validator: (v) =>
                  Validators.positiveNumber(v, field: 'Total area'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Soil type (optional)',
              controller: _soil,
              prefixIcon: Icons.terrain,
              hint: 'e.g. Clay loam',
            ),
            const SizedBox(height: 18),
            _PreviousCropsPicker(
              selected: _previousCrops,
              onToggle: (id) => setState(() {
                _previousCrops.contains(id)
                    ? _previousCrops.remove(id)
                    : _previousCrops.add(id);
              }),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Previous farming activities (optional)',
              controller: _activities,
              hint: 'e.g. Rice paddy in wet season, vegetables in dry season',
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
              label: Text(_isEdit ? 'Save Changes' : 'Create Farm Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousCropsPicker extends StatelessWidget {
  const _PreviousCropsPicker({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Previously planted crops',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text('Helps the recommender weigh your experience.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in CropCatalog.crops)
              FilterChip(
                label: Text(c.name),
                selected: selected.contains(c.id),
                onSelected: (_) => onToggle(c.id),
              ),
          ],
        ),
      ],
    );
  }
}
