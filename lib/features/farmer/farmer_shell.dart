import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common_widgets.dart';
import '../../providers/core_providers.dart';
import 'advisory_screen.dart';
import 'dashboard_screen.dart';
import 'declarations_screen.dart';
import 'profile_screen.dart';
import 'records_screen.dart';

/// The Farmer portal scaffold. Hosts the five primary destinations in an
/// [IndexedStack] (so each tab keeps its state) under a Material 3
/// [NavigationBar]. Covers study Objectives 1, 2, and 4.
class FarmerShell extends ConsumerStatefulWidget {
  const FarmerShell({super.key});

  @override
  ConsumerState<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends ConsumerState<FarmerShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    FarmerDashboardScreen(),
    DeclarationsScreen(),
    AdvisoryScreen(),
    RecordsScreen(),
    FarmerProfileScreen(),
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
          Expanded(
            child: IndexedStack(index: _index, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.eco_outlined),
              selectedIcon: Icon(Icons.eco),
              label: 'Crops'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Advisory'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Records'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account'),
        ],
      ),
    );
  }
}
