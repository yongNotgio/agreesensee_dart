import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logic/crop_calendar_engine.dart';
import '../../core/logic/recommendation_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/agronomy_dataset.dart';
import '../../models/crop_declaration.dart';
import '../../models/enums.dart';
import '../../models/farm.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import 'widgets/pre_declaration_risk_panel.dart';

/// Create or edit a crop declaration.
///
/// Two things changed here on the adviser's instruction. The farmer is no
/// longer asked to type an expected yield or a projected price — figures they
/// cannot know, which the app then presented back as analysis. Both are now
/// derived from the calibrated dataset and the barangay's suitability, and
/// shown read-only in the risk panel. And with the MAO approval chain removed,
/// the risk panel is the only thing standing between a farmer and planting into
/// a glut, so it sits directly under the crop picker and updates live.
class DeclarationFormScreen extends ConsumerStatefulWidget {
  const DeclarationFormScreen({super.key, this.existing});

  final CropDeclaration? existing;

  @override
  ConsumerState<DeclarationFormScreen> createState() =>
      _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends ConsumerState<DeclarationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _area = TextEditingController();
  final _notes = TextEditingController();

  String _cropId = CropCatalog.crops.first.id;
  String? _variety;
  DateTime _plantingDate = DateTime.now();
  String? _barangay;
  final Set<String> _companions = {};
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  AgronomyDataset get _agronomy => ref.read(agronomyDatasetProvider);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cropId = e.cropId;
      _variety = e.variety;
      _area.text = e.areaHa.toString();
      _notes.text = e.notes ?? '';
      _plantingDate = e.plantingDate;
      _barangay = e.barangay;
      _companions.addAll(e.companionCropIds);
    } else {
      _barangay = ref.read(currentProfileProvider)?.barangay;
      _variety = _defaultVarietyFor(_cropId);
    }
  }

  String? _defaultVarietyFor(String cropId) {
    final list = ref.read(agronomyDatasetProvider).varietiesFor(cropId);
    return list.isEmpty ? null : list.first.name;
  }

  @override
  void dispose() {
    _area.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _areaValue => double.tryParse(_area.text.replaceAll(',', '')) ?? 0;

  /// Harvest date derived from the selected variety's maturity period.
  DateTime get _harvestDate => CropCalendarEngine.harvestDateFor(
        cropId: _cropId,
        plantingDate: _plantingDate,
        agronomy: _agronomy,
        variety: _variety,
        fallbackGrowthDays: CropCatalog.byIdOrFirst(_cropId).growthDurationDays,
      );

  /// Seedbed date for nursery-raised crops — null when direct-seeded.
  DateTime? get _sowingDate => CropCalendarEngine.sowingDateFor(
        cropId: _cropId,
        plantingDate: _plantingDate,
        agronomy: _agronomy,
      );

  /// Hectares still available on the farm after existing active declarations.
  double _availableArea(Farm farm, double committed) {
    // When editing, the declaration's own area is not a competing claim.
    final own = _isEdit && widget.existing!.farmId == farm.id
        ? widget.existing!.areaHa
        : 0.0;
    return farm.totalAreaHa - committed + own;
  }

  Future<void> _submit(DeclarationRisk? risk) async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null) {
      _toast('Please select a barangay');
      return;
    }
    if (_variety == null) {
      _toast('Please select a variety');
      return;
    }
    final profile = ref.read(currentProfileProvider);
    final farm = await ref.read(primaryFarmProvider.future);
    if (profile == null) return;
    if (farm == null) {
      _toast('Set up your farm profile first (Account tab).');
      return;
    }

    // Warn — never block. The farmer decides what to plant on their own land.
    if (risk != null && risk.isHigh && mounted) {
      final proceed = await _confirmHighRisk(risk);
      if (proceed != true) return;
    }

    setState(() => _submitting = true);
    try {
      final base = widget.existing;
      final declaration = CropDeclaration(
        id: base?.id ?? IdGen.uuid(),
        farmerId: profile.id,
        farmId: farm.id,
        cropId: _cropId,
        variety: _variety!,
        areaHa: _areaValue,
        plantingDate: _plantingDate,
        seedlingSowingDate: _sowingDate,
        expectedHarvestDate: _harvestDate,
        // System-derived, not farmer-entered.
        expectedYieldKg: risk?.expectedYieldKg ?? _fallbackYield(),
        projectedPricePerKg: risk?.projectedPricePerKg ??
            CropCatalog.byIdOrFirst(_cropId).baselinePricePerKg,
        riskAtDeclaration: risk?.verdict.wire,
        barangay: _barangay!,
        status: base?.status ?? DeclarationStatus.active,
        companionCropIds: _companions.toList(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: base?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(appActionsProvider).saveDeclaration(declaration);
      if (mounted) {
        Navigator.of(context).pop();
        _toast(_isEdit
            ? 'Declaration updated — crop calendar rescheduled'
            : 'Crop declared — your activity calendar is ready');
      }
    } on Object catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double _fallbackYield() {
    final cal = ref.read(calibrationProvider)[_cropId];
    final perHa =
        cal?.meanYieldKgPerHa ?? CropCatalog.byIdOrFirst(_cropId).baselineYieldPerHa;
    return perHa * _areaValue;
  }

  Future<bool?> _confirmHighRisk(DeclarationRisk risk) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: AppColors.riskHigh, size: 32),
        title: const Text('This looks high risk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reason in risk.reasons.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            if (risk.alternatives.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Better options right now:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final alt in risk.alternatives)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                      '${alt.crop.name} — ${alt.saturation.level.label.toLowerCase()}, '
                      '${alt.scorePercent}% match'),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Choose another crop'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Declare anyway'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final agronomy = ref.watch(agronomyDatasetProvider);
    final varieties = agronomy.varietiesFor(_cropId);
    final companionOptions = CropCatalog.crops.where((c) => c.id != _cropId);
    final farmAsync = ref.watch(primaryFarmProvider);

    // Live risk assessment for whatever is currently selected in the form.
    final barangay = _barangay;
    final risk = barangay == null || _areaValue <= 0
        ? null
        : ref.watch(recommendationsForBarangayProvider(barangay)).maybeWhen(
              orElse: () => null,
              data: (ranked) => ranked.isEmpty
                  ? null
                  : RecommendationEngine.assess(
                      cropId: _cropId,
                      areaHa: _areaValue,
                      barangay: barangay,
                      plantingDate: _plantingDate,
                      ranked: ranked,
                      calibration: ref.watch(calibrationProvider)[_cropId],
                    ),
            );

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
                  _variety = _defaultVarietyFor(v);
                });
              },
            ),
            const SizedBox(height: 14),

            // Variety is a bounded choice, not free text — twelve spellings of
            // the same variety cannot be aggregated for analysis.
            if (varieties.isEmpty)
              AppTextField(
                label: 'Variety',
                initialValue: _variety,
                prefixIcon: Icons.label_outline,
                validator: (v) => Validators.required(v, field: 'Variety'),
                onChanged: (v) => _variety = v.trim(),
              )
            else
              AppDropdown<String>(
                label: 'Variety',
                value: varieties.any((x) => x.name == _variety) ? _variety : null,
                prefixIcon: Icons.label_outline,
                items: varieties.map((x) => x.name).toList(),
                itemLabel: (name) {
                  final v = agronomy.variety(_cropId, name);
                  return v == null
                      ? name
                      : '$name • ${v.maturityDays}d';
                },
                validator: (v) => v == null ? 'Select a variety' : null,
                onChanged: (v) => setState(() => _variety = v),
              ),
            if (_variety != null && varieties.isNotEmpty) ...[
              const SizedBox(height: 6),
              _VarietyNote(
                  notes: agronomy.variety(_cropId, _variety!)?.notes ?? ''),
            ],
            const SizedBox(height: 14),

            // Area validated against the land the farmer actually has.
            farmAsync.maybeWhen(
              orElse: () => _AreaField(controller: _area, onChanged: _refresh),
              data: (farm) {
                if (farm == null) {
                  return _AreaField(controller: _area, onChanged: _refresh);
                }
                return ref.watch(committedAreaProvider(farm.id)).maybeWhen(
                      orElse: () =>
                          _AreaField(controller: _area, onChanged: _refresh),
                      data: (committed) {
                        final available = _availableArea(farm, committed);
                        return _AreaField(
                          controller: _area,
                          onChanged: _refresh,
                          availableHa: available,
                          totalHa: farm.totalAreaHa,
                        );
                      },
                    );
              },
            ),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'Barangay',
              value: _barangay,
              prefixIcon: Icons.location_on_outlined,
              items: AppConstants.barangays,
              itemLabel: (b) => b,
              validator: (v) => v == null ? 'Select a barangay' : null,
              onChanged: (v) => setState(() => _barangay = v),
            ),
            const SizedBox(height: 16),

            // The live guardrail.
            PreDeclarationRiskPanel(risk: risk, areaHa: _areaValue),
            const SizedBox(height: 16),

            AppDateField(
              label: agronomy.usesSeedlings(_cropId)
                  ? 'Transplanting date'
                  : 'Sowing date',
              value: _plantingDate,
              onChanged: (d) => setState(() => _plantingDate = d),
            ),
            const SizedBox(height: 10),
            _CycleSummary(
              cropId: _cropId,
              sowingDate: _sowingDate,
              plantingDate: _plantingDate,
              harvestDate: _harvestDate,
              agronomy: agronomy,
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
              hint: 'Anything worth remembering about this planting',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(risk),
              icon: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Save Changes' : 'Declare Crop'),
            ),
            const SizedBox(height: 8),
            Text(
              'Declaring records what you are planting so the municipality can '
              'track supply. It is not an application — nobody has to approve it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() => setState(() {});
}

/// Area input that knows how much land is left to plant.
class _AreaField extends StatelessWidget {
  const _AreaField({
    required this.controller,
    required this.onChanged,
    this.availableHa,
    this.totalHa,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final double? availableHa;
  final double? totalHa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = availableHa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Area to plant (ha)',
          controller: controller,
          prefixIcon: Icons.crop_landscape,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: AppTextField.decimal,
          validator: (v) {
            final base = Validators.positiveNumber(v, field: 'Area');
            if (base != null) return base;
            if (available == null) return null;
            final entered = double.tryParse(v!.replaceAll(',', '')) ?? 0;
            if (entered > available + 0.0001) {
              return available <= 0
                  ? 'All of your land is already planted. Harvest or cancel a '
                      'declaration first.'
                  : 'You only have ${Fmt.area(available)} left to plant';
            }
            return null;
          },
          onChanged: (_) => onChanged(),
        ),
        if (available != null && totalHa != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.landscape_outlined,
                  size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${Fmt.area(available.clamp(0, double.infinity))} available '
                'of ${Fmt.area(totalHa!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VarietyNote extends StatelessWidget {
  const _VarietyNote({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.info_outline,
            size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Expanded(
          child: Text(notes,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// The growth cycle from seedbed to harvest — the "planting cycle halin sa
/// seedlings" view. A single flat growth-duration number could not show this.
class _CycleSummary extends StatelessWidget {
  const _CycleSummary({
    required this.cropId,
    required this.sowingDate,
    required this.plantingDate,
    required this.harvestDate,
    required this.agronomy,
  });

  final String cropId;
  final DateTime? sowingDate;
  final DateTime plantingDate;
  final DateTime harvestDate;
  final AgronomyDataset agronomy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nursery = agronomy.nurseryDaysFor(cropId);
    final totalDays = harvestDate.difference(sowingDate ?? plantingDate).inDays;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, size: 17, color: AppColors.info),
              const SizedBox(width: 8),
              Text('Growth cycle • $totalDays days total',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (sowingDate != null)
            _Step(
              icon: Icons.spa_outlined,
              label: 'Sow in seedbed',
              value: '${Fmt.date(sowingDate)} • $nursery days in nursery',
            ),
          _Step(
            icon: sowingDate != null ? Icons.agriculture : Icons.grass,
            label: sowingDate != null ? 'Transplant to field' : 'Direct sow',
            value: Fmt.date(plantingDate),
          ),
          _Step(
            icon: Icons.shopping_basket_outlined,
            label: 'First harvest',
            value: Fmt.date(harvestDate),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 116,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
