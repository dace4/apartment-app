import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../view_models/maintenance_reminders_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../../router/app_routes.dart';
import '../../services/widgets/maintenance_reminder_banner.dart';

/// Bottom navigation shell. Each tab keeps its own navigation stack.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.authViewModel,
    required this.remindersViewModel,
  });

  final StatefulNavigationShell navigationShell;
  final AuthViewModel authViewModel;

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
    final indices = [
      0,
      if (authViewModel.canAccess(AppRoutes.favourites)) 1,
      if (authViewModel.canAccess(AppRoutes.applications)) 2,
      3,
      4,
    ];
    return NavigationBar(
      selectedIndex: indices.contains(navigationShell.currentIndex)
          ? indices.indexOf(navigationShell.currentIndex)
          : 0,
      onDestinationSelected: (index) => navigationShell.goBranch(
        indices[index],
        // Tapping the active tab again returns to its first page.
        initialLocation: indices[index] == navigationShell.currentIndex,
      ),
      destinations: [
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        if (authViewModel.canAccess(AppRoutes.favourites))
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
        if (authViewModel.canAccess(AppRoutes.applications))
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
