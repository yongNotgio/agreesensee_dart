import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_card.dart';
import '../../models/farm.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';
import 'farm_form_screen.dart';

/// Account tab: farmer identity, farm profile (Phase 1), lifetime stats, and
/// sign-out.
class FarmerProfileScreen extends ConsumerWidget {
  const FarmerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final farmAsync = ref.watch(primaryFarmProvider);
    final declarationsAsync = ref.watch(declarationsProvider);
    final coopAsync = ref.watch(cooperativeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity header.
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(profile?.initials ?? 'F',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.fullName ?? 'Farmer',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(profile?.role.label ?? '',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                    if (profile?.barangay != null)
                      Text('Brgy. ${profile!.barangay} • ${AppConfig.municipality}',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lifetime stats.
          declarationsAsync.maybeWhen(
            orElse: () => const SizedBox.shrink(),
            data: (declarations) {
              final harvested =
                  declarations.where((d) => d.status.name == 'harvested').length;
              final totalArea =
                  declarations.fold<double>(0, (s, d) => s + d.areaHa);
              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  MetricTile(
                      label: 'Declarations',
                      value: '${declarations.length}',
                      icon: Icons.eco),
                  MetricTile(
                      label: 'Harvested',
                      value: '$harvested',
                      icon: Icons.agriculture,
                      color: AppColors.tertiary),
                  MetricTile(
                      label: 'Total area',
                      value: Fmt.area(totalArea),
                      icon: Icons.crop_landscape,
                      color: AppColors.secondary),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Contact info.
          SectionCard(
            title: 'Contact information',
            icon: Icons.contact_page_outlined,
            child: Column(
              children: [
                InfoRow(
                    label: 'Email',
                    value: profile?.email ?? '—',
                    icon: Icons.email_outlined),
                InfoRow(
                    label: 'Contact number',
                    value: profile?.contactNumber ?? '—',
                    icon: Icons.phone_outlined),
                coopAsync.maybeWhen(
                  orElse: () => const SizedBox.shrink(),
                  data: (coop) => InfoRow(
                      label: 'Cooperative',
                      value: coop?.name ?? 'Not a member',
                      icon: Icons.groups_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Farm profile.
          AsyncValueView(
            value: farmAsync,
            onRetry: () => ref.invalidate(primaryFarmProvider),
            loading: const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator())),
            data: (farm) => _FarmCard(farm: farm),
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
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${AppConfig.appName} • ${AppConfig.appTagline}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.farm});
  final Farm? farm;

  @override
  Widget build(BuildContext context) {
    if (farm == null) {
      return SectionCard(
        title: 'Farm profile',
        icon: Icons.agriculture_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Set up your farm profile to declare crops and get recommendations.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FarmFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Create farm profile'),
            ),
          ],
        ),
      );
    }
    return SectionCard(
      title: 'Farm profile',
      icon: Icons.agriculture_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FarmFormScreen(existing: farm))),
      ),
      child: Column(
        children: [
          InfoRow(label: 'Name', value: farm!.name),
          InfoRow(label: 'Barangay', value: farm!.barangay),
          InfoRow(label: 'Total area', value: Fmt.area(farm!.totalAreaHa)),
          if (farm!.soilType != null)
            InfoRow(label: 'Soil type', value: farm!.soilType!),
          if (farm!.previousCrops.isNotEmpty)
            InfoRow(
                label: 'Previous crops',
                value: farm!.previousCrops
                    .map((e) => e.replaceAll('_', ' '))
                    .join(', ')),
        ],
      ),
    );
  }
}
