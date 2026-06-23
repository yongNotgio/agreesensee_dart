import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common_widgets.dart';
import '../../providers/core_providers.dart';
import 'coop_dashboard_screen.dart';
import 'coop_profile_screen.dart';
import 'supply_projection_screen.dart';
import 'surplus_screen.dart';

/// The Cooperative / Association portal scaffold. Hosts the supply-chain
/// dashboard, supply projection, surplus/buy-back routing, and account tabs.
/// Implements study Objective 3.
class CoopShell extends ConsumerStatefulWidget {
  const CoopShell({super.key});

  @override
  ConsumerState<CoopShell> createState() => _CoopShellState();
}

class _CoopShellState extends ConsumerState<CoopShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    CoopDashboardScreen(),
    SupplyProjectionScreen(),
    SurplusScreen(),
    CoopProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoModeProvider);
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Scaffold(
      body: Column(
        children: [
          if (isDemo)
            const OfflineBanner(demoMode: true)
          else if (!online)
            const OfflineBanner(),
          Expanded(child: IndexedStack(index: _index, children: _tabs)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.stacked_line_chart_outlined),
              selectedIcon: Icon(Icons.stacked_line_chart),
              label: 'Supply'),
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Surplus'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Association'),
        ],
      ),
    );
  }
}
