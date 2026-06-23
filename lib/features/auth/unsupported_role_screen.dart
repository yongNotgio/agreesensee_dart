import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common_widgets.dart';
import '../../providers/auth_controller.dart';

/// Shown when an admin-class role (MAO / Technician / BAW) signs into the mobile
/// app. Their dashboards live on the web client per the manuscript scope, so we
/// explain that and offer a sign-out.
class UnsupportedRoleScreen extends ConsumerWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriSense'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: EmptyState(
        icon: Icons.desktop_windows,
        title: '${profile?.role.label ?? 'This role'} uses the web dashboard',
        message:
            'The mobile app hosts the Farmer and Cooperative portals. Validation '
            'and supply-chain governance tools for your role are available on the '
            'AgriSense web dashboard.',
        actionLabel: 'Sign out',
        onAction: () => ref.read(authControllerProvider.notifier).signOut(),
      ),
    );
  }
}
