import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../view_models/maintenance_reminders_view_model.dart';
import '../../../view_models/auth_view_model.dart';
import '../../../view_models/notifications_view_model.dart';
import '../../../router/app_routes.dart';
import '../../services/widgets/maintenance_reminder_banner.dart';

/// Bottom navigation shell. Each tab keeps its own navigation stack.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.authViewModel,
    required this.remindersViewModel,
    required this.notificationsViewModel,
  });

  final StatefulNavigationShell navigationShell;
  final AuthViewModel authViewModel;

  /// US-17: due maintenance reminders, shown above the tabs on every page.
  final MaintenanceRemindersViewModel remindersViewModel;

  /// US-20: unread notifications put a red dot on the Profile tab.
  final NotificationsViewModel notificationsViewModel;

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
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
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
          icon: _withUnreadDot(const Icon(Icons.person_outline)),
          selectedIcon: _withUnreadDot(const Icon(Icons.person)),
          label: 'Profile',
        ),
      ],
    );
  }

  /// US 18.3: a red badge with the number of unread notifications, shared
  /// with the Notifications tile and updated live.
  Widget _withUnreadDot(Widget icon) => ListenableBuilder(
    listenable: notificationsViewModel,
    builder: (context, _) => Badge.count(
      count: notificationsViewModel.alertCount,
      isLabelVisible: notificationsViewModel.alertCount > 0,
      child: icon,
    ),
  );
}
