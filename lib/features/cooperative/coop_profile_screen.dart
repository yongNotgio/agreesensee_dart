import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_card.dart';
import '../../models/crop_declaration.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

/// Cooperative account: association profile, member-supply monitoring (which
/// crops members are growing and how much), and sign-out.
class CoopProfileScreen extends ConsumerWidget {
  const CoopProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final coopAsync = ref.watch(cooperativeProvider);
    final declarationsAsync = ref.watch(allDeclarationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Association')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          coopAsync.maybeWhen(
            orElse: () => const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
            data: (coop) => Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  child: const Icon(Icons.groups,
                      size: 30, color: AppColors.secondary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coop?.name ?? 'Cooperative',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(
                          'Administered by ${profile?.fullName ?? '—'}',
                          style: Theme.of(context).textTheme.bodySmall),
                      if (coop != null)
                        Text('Brgy. ${coop.barangay} • ${AppConfig.municipality}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          coopAsync.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (coop) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                MetricTile(
                    label: 'Members',
                    value: '${coop?.memberCount ?? 0}',
                    icon: Icons.groups),
                MetricTile(
                    label: 'Buy-back capacity',
                    value: coop?.buyBackCapacityTons == null
                        ? '—'
                        : Fmt.tons(coop!.buyBackCapacityTons!),
                    icon: Icons.warehouse,
                    color: AppColors.tertiary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AsyncValueView(
            value: declarationsAsync,
            onRetry: () => ref.invalidate(allDeclarationsProvider),
            data: (declarations) => _MemberSupply(declarations: declarations),
          ),
          const SizedBox(height: 12),
          coopAsync.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (coop) => coop?.contactNumber == null
                ? const SizedBox.shrink()
                : SectionCard(
                    title: 'Contact',
                    icon: Icons.contact_page_outlined,
                    child: Column(
                      children: [
                        InfoRow(
                            label: 'Contact person',
                            value: coop?.contactPerson ?? '—',
                            icon: Icons.person_outline),
                        InfoRow(
                            label: 'Phone',
                            value: coop?.contactNumber ?? '—',
                            icon: Icons.phone_outlined),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Aggregates active member declarations by crop to show what the association's
/// members are collectively producing.
class _MemberSupply extends StatelessWidget {
  const _MemberSupply({required this.declarations});
  final List<CropDeclaration> declarations;

  @override
  Widget build(BuildContext context) {
    final active = declarations.where((d) => d.status.isActive).toList();
    final byCrop = <String, ({double tons, Set<String> farmers})>{};
    for (final d in active) {
      final existing =
          byCrop[d.cropId] ?? (tons: 0.0, farmers: <String>{});
      byCrop[d.cropId] = (
        tons: existing.tons + d.expectedYieldTons,
        farmers: existing.farmers..add(d.farmerId),
      );
    }
    final rows = byCrop.entries.toList()
      ..sort((a, b) => b.value.tons.compareTo(a.value.tons));

    return SectionCard(
      title: 'Member supply monitoring',
      subtitle: '${active.length} active declarations',
      icon: Icons.insights,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No active member declarations yet.'),
            )
          : Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.spa,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r.key.replaceAll('_', ' '),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text('${r.value.farmers.length} farmer(s)',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Text(Fmt.tons(r.value.tons),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
