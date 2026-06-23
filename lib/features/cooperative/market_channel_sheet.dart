import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/cooperative.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';

/// Opens the modal sheet to register a buy-back program or alternative market
/// channel for the cooperative (Objective 3).
Future<void> showMarketChannelSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MarketChannelSheet(),
  );
}

const _channelTypes = <(String, String)>[
  ('buy_back', 'Association Buy-back'),
  ('institutional_buyer', 'Institutional Buyer'),
  ('processor', 'Processor / Agri-business'),
  ('neighboring_market', 'Neighboring Market'),
];

class _MarketChannelSheet extends ConsumerStatefulWidget {
  const _MarketChannelSheet();

  @override
  ConsumerState<_MarketChannelSheet> createState() =>
      _MarketChannelSheetState();
}

class _MarketChannelSheetState extends ConsumerState<_MarketChannelSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _capacity = TextEditingController();
  final _price = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();

  String _type = 'buy_back';
  final Set<String> _crops = {};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _price.dispose();
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final coopId = ref.read(currentProfileProvider)?.cooperativeId;
    if (coopId == null) return;
    setState(() => _saving = true);
    final channel = MarketChannel(
      id: IdGen.uuid(),
      cooperativeId: coopId,
      name: _name.text.trim(),
      type: _type,
      capacityTons: double.parse(_capacity.text.replaceAll(',', '')),
      cropIds: _crops.toList(),
      pricePerKg: double.tryParse(_price.text.replaceAll(',', '')),
      contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await ref.read(appActionsProvider).saveMarketChannel(channel);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Add market channel',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Channel type',
              value: _type,
              items: _channelTypes.map((e) => e.$1).toList(),
              itemLabel: (id) =>
                  _channelTypes.firstWhere((e) => e.$1 == id).$2,
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Name',
              controller: _name,
              hint: 'e.g. Iloilo City Terminal Market',
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Capacity (tons)',
                    controller: _capacity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppTextField.decimal,
                    validator: (v) =>
                        Validators.positiveNumber(v, field: 'Capacity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Price ₱/kg',
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: AppTextField.decimal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Contact (optional)',
              controller: _contact,
              prefixIcon: Icons.contact_phone_outlined,
            ),
            const SizedBox(height: 14),
            Text('Crops accepted',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in CropCatalog.crops)
                  FilterChip(
                    label: Text(c.name),
                    selected: _crops.contains(c.id),
                    onSelected: (_) => setState(() {
                      _crops.contains(c.id)
                          ? _crops.remove(c.id)
                          : _crops.add(c.id);
                    }),
                  ),
              ],
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
              label: const Text('Save channel'),
            ),
          ],
        ),
      ),
    );
  }
}
