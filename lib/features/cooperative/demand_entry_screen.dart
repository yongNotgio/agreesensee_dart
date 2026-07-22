import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_gen.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/demand_signal.dart';
import '../../models/enums.dart';
import '../../providers/app_actions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// Where a cooperative declares the volume it can actually absorb.
///
/// The Market Saturation Index divides projected supply by demand, and demand
/// was a single hardcoded annual constant per crop — unverifiable, and
/// impossible for anyone on the ground to correct. Cooperatives are the ones
/// who buy the produce, so this is where the denominator gets its evidence.
class DemandEntryScreen extends ConsumerWidget {
  const DemandEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(myDemandSignalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Declare Demand')),
      floatingActionButton: FloatingActionButton.extended(
        // CoopShell's IndexedStack keeps every tab mounted at once, so this
        // needs its own tag — see dashboard_screen.dart's FAB for why.
        heroTag: 'demand-fab',
        onPressed: () => showDemandSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Declare demand'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myDemandSignalsProvider),
        child: AsyncValueView(
          value: signalsAsync,
          onRetry: () => ref.invalidate(myDemandSignalsProvider),
          data: (signals) {
            final active = signals.where((s) => s.isActive).toList();
            final past = signals.where((s) => !s.isActive).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                const _Explainer(),
                const SizedBox(height: 12),
                if (signals.isEmpty)
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No demand declared',
                    message:
                        'Tell AgriSense how much of each crop your association '
                        'can absorb. Oversupply warnings shown to farmers are '
                        'measured against this, instead of a fixed estimate.',
                    actionLabel: 'Declare demand',
                    onAction: () => showDemandSheet(context, ref),
                  )
                else ...[
                  _SectionTitle('In force now (${active.length})'),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'No commitment covers today — farmers currently see '
                          'the municipal baseline instead.'),
                    )
                  else
                    for (final s in active) _SignalCard(signal: s, active: true),
                  if (past.isNotEmpty) ...[
                    _SectionTitle('Other periods'),
                    for (final s in past) _SignalCard(signal: s, active: false),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Volumes you declare here become the demand side of the Market '
              'Saturation Index for every farmer in the municipality. Declare '
              'what you can genuinely take, for the period you can take it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _SignalCard extends ConsumerWidget {
  const _SignalCard({required this.signal, required this.active});
  final DemandSignal signal;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = active ? AppColors.success : theme.colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(signal.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) =>
            ref.read(appActionsProvider).deleteDemandSignal(signal.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(Icons.storefront, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(signal.cropName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(signal.buyerType.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.tons(signal.demandTons),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (signal.pricePerKg != null)
                        Text('${Fmt.peso(signal.pricePerKg!)}/kg',
                            style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.date_range,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Fmt.dateShort(signal.periodStart)} – '
                      '${Fmt.date(signal.periodEnd)} '
                      '(${signal.durationDays} days)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (signal.buyerName != null) ...[
                const SizedBox(height: 4),
                Text('Buyer: ${signal.buyerName}',
                    style: theme.textTheme.bodySmall),
              ],
              if (signal.notes != null) ...[
                const SizedBox(height: 6),
                Text(signal.notes!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the modal sheet for declaring a new demand commitment.
Future<void> showDemandSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DemandSheet(),
  );
}

class _DemandSheet extends ConsumerStatefulWidget {
  const _DemandSheet();

  @override
  ConsumerState<_DemandSheet> createState() => _DemandSheetState();
}

class _DemandSheetState extends ConsumerState<_DemandSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tons = TextEditingController();
  final _price = TextEditingController();
  final _buyer = TextEditingController();
  final _notes = TextEditingController();

  String _cropId = CropCatalog.crops.first.id;
  BuyerType _buyerType = BuyerType.bagsakan;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _tons.dispose();
    _price.dispose();
    _buyer.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      _toast('The end date must come after the start date.');
      return;
    }
    final coopId = ref.read(currentProfileProvider)?.cooperativeId;
    if (coopId == null) {
      _toast('Your account is not linked to a cooperative yet.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(appActionsProvider).saveDemandSignal(
            DemandSignal(
              id: IdGen.uuid(),
              cooperativeId: coopId,
              cropId: _cropId,
              periodStart: _start,
              periodEnd: _end,
              demandTons: double.parse(_tons.text.replaceAll(',', '')),
              buyerType: _buyerType,
              pricePerKg: double.tryParse(_price.text.replaceAll(',', '')),
              buyerName:
                  _buyer.text.trim().isEmpty ? null : _buyer.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Declare demand',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('How much can your association absorb, and by when?',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              AppDropdown<String>(
                label: 'Crop',
                value: _cropId,
                prefixIcon: Icons.eco,
                items: CropCatalog.crops.map((c) => c.id).toList(),
                itemLabel: CropCatalog.nameFor,
                onChanged: (v) => setState(() => _cropId = v ?? _cropId),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Volume you can absorb (tons)',
                controller: _tons,
                prefixIcon: Icons.scale,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppTextField.decimal,
                validator: (v) => Validators.positiveNumber(v, field: 'Volume'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppDateField(
                      label: 'From',
                      value: _start,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      onChanged: (d) => setState(() => _start = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDateField(
                      label: 'To',
                      value: _end,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      onChanged: (d) => setState(() => _end = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppDropdown<BuyerType>(
                label: 'Buyer type',
                value: _buyerType,
                prefixIcon: Icons.storefront,
                items: BuyerType.values,
                itemLabel: (b) => b.label,
                onChanged: (v) => setState(() => _buyerType = v ?? _buyerType),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Buyer name (optional)',
                controller: _buyer,
                prefixIcon: Icons.business_outlined,
                hint: 'e.g. Tubungan Bagsakan, DepEd feeding program',
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Indicative price (₱/kg, optional)',
                controller: _price,
                prefixIcon: Icons.sell_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppTextField.decimal,
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
                label: const Text('Save commitment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
