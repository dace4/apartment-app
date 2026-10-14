import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../view_models/maintenance_reminders_view_model.dart';
import '../../services/widgets/maintenance_reminder_banner.dart';

/// Bottom navigation shell. Each tab keeps its own navigation stack.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.remindersViewModel,
  });

  final StatefulNavigationShell navigationShell;

  /// US-17: due maintenance reminders, shown above the tabs on every page.
  final MaintenanceRemindersViewModel remindersViewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaintenanceReminderBanner(viewModel: remindersViewModel),
          _navigationBar(),
        ],
      ),
    );
  }

  Widget _navigationBar() {
    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        // Tapping the active tab again returns to its first page.
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite),
          label: 'Favourites',
        ),
        NavigationDestination(
          icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description),
          label: 'Applications',
        ),
        NavigationDestination(
          icon: Icon(Icons.home_repair_service_outlined),
          selectedIcon: Icon(Icons.home_repair_service),
          label: 'Services',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
