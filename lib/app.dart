import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'view_models/apartments_view_model.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/compare_view_model.dart';
import 'view_models/favourites_view_model.dart';
import 'view_models/maintenance_reminders_view_model.dart';
import 'view_models/visit_reminders_view_model.dart';
import 'view_models/notifications_view_model.dart';
import 'view_models/saved_searches_view_model.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({super.key});

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  final auth = AuthViewModel();
  @override
  void dispose() {
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      final user = auth.user;
      final roles = user?.roles.map((role) => role.name).toList() ?? [];
      roles.sort();
      // US-07: dispose retained routes, listeners and private data on changes.
      return _SessionApp(
        key: ValueKey(
          '${user?.id}:${user?.emailVerified}:${user?.rolesLoaded}:${user?.profileError}:$roles',
        ),
        authViewModel: auth,
      );
    },
  );
}

class _SessionApp extends StatefulWidget {
  const _SessionApp({super.key, required this.authViewModel});
  final AuthViewModel authViewModel;
  @override
  State<_SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<_SessionApp> {
  // ViewModels shared by several screens are created once, here
  // (see ARCHITECTURE.md §4).
  AuthViewModel get _authViewModel => widget.authViewModel;
  final _apartmentsViewModel = ApartmentsViewModel();
  late final _compareViewModel = CompareViewModel(
    allowed:
        _authViewModel.user?.isReady == true && _authViewModel.user!.isConsumer,
  );
  final _favouritesViewModel = FavouritesViewModel();
  // US-17: the in-app maintenance reminder shown on every tab.
  final _maintenanceRemindersViewModel = MaintenanceRemindersViewModel();
  // US 18.4: "Visit tomorrow" notifications for renters and buyers.
  final _visitRemindersViewModel = VisitRemindersViewModel();
  // US-23: saved searches, and alerts for new matching offers on every tab.
  final _savedSearchesViewModel = SavedSearchesViewModel();
  // US-18/20: the notification list and the red dot for unread ones, shown
  // on the Profile tab and the Notifications tile.
  final _notificationsViewModel = NotificationsViewModel();

  late final GoRouter _router = createAppRouter(
    authViewModel: _authViewModel,
    apartmentsViewModel: _apartmentsViewModel,
    compareViewModel: _compareViewModel,
    favouritesViewModel: _favouritesViewModel,
    maintenanceRemindersViewModel: _maintenanceRemindersViewModel,
    savedSearchesViewModel: _savedSearchesViewModel,
    notificationsViewModel: _notificationsViewModel,
  );

  @override
  void initState() {
    super.initState();
    // firestore.rules only let verified users with roles read notifications.
    // A new session (see HomeFlowApp) starts listening again.
    if (_authViewModel.user?.isReady == true) _notificationsViewModel.listen();
  }

  @override
  void dispose() {
    _router.dispose();

    _apartmentsViewModel.dispose();
    _compareViewModel.dispose();
    _favouritesViewModel.dispose();
    _maintenanceRemindersViewModel.dispose();
    _visitRemindersViewModel.dispose();
    _savedSearchesViewModel.dispose();
    _notificationsViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HomeFlow',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
      routerConfig: _router,
    );
  }
}
