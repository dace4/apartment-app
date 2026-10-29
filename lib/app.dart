import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'view_models/apartments_view_model.dart';
import 'view_models/app_maintenance_view_model.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/compare_view_model.dart';
import 'view_models/favourites_view_model.dart';
import 'view_models/visit_reminders_view_model.dart';
import 'view_models/notifications_view_model.dart';
import 'view_models/saved_searches_view_model.dart';
import 'views/shared/widgets/app_maintenance_banner.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({super.key});

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  final auth = AuthViewModel();
  // App maintenance windows also apply before log in (banner on every page).
  final maintenance = AppMaintenanceViewModel()..listen();

  @override
  void dispose() {
    auth.dispose();
    maintenance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([auth, maintenance]),
    builder: (context, _) {
      final user = auth.user;
      final roles = user?.roles.map((role) => role.name).toList() ?? [];
      roles.sort();
      // Every open session of a non-admin goes down when maintenance starts.
      final blocked = maintenance.isActive && user?.isAdmin != true;
      // US-07: dispose retained routes, listeners and private data on changes.
      return _SessionApp(
        key: ValueKey(
          '${user?.id}:${user?.emailVerified}:${user?.rolesLoaded}:${user?.profileError}:$roles:$blocked',
        ),
        authViewModel: auth,
        appMaintenanceViewModel: maintenance,
        blocked: blocked,
      );
    },
  );
}

class _SessionApp extends StatefulWidget {
  const _SessionApp({
    super.key,
    required this.authViewModel,
    required this.appMaintenanceViewModel,
    required this.blocked,
  });
  final AuthViewModel authViewModel;
  final AppMaintenanceViewModel appMaintenanceViewModel;
  final bool blocked;
  @override
  State<_SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<_SessionApp> {
  // ViewModels shared by several screens are created once, here
  // (see ARCHITECTURE.md §4).
  AuthViewModel get _authViewModel => widget.authViewModel;
  late final _apartmentsViewModel = ApartmentsViewModel(
    user: _authViewModel.user,
  );
  late final _compareViewModel = CompareViewModel(
    allowed:
        _authViewModel.user?.isReady == true && _authViewModel.user!.isConsumer,
  );
  late final _favouritesViewModel = FavouritesViewModel(
    user: _authViewModel.user,
  );
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
    appMaintenanceViewModel: widget.appMaintenanceViewModel,
    savedSearchesViewModel: _savedSearchesViewModel,
    notificationsViewModel: _notificationsViewModel,
  );

  @override
  void initState() {
    super.initState();
    // firestore.rules only let verified users with roles read notifications.
    // A new session (see HomeFlowApp) starts listening again.
    // During maintenance firestore.rules refuse it: do not listen.
    if (_authViewModel.user?.isReady == true && !widget.blocked) {
      _notificationsViewModel.listen();
    }
  }

  @override
  void dispose() {
    _router.dispose();

    _apartmentsViewModel.dispose();
    _compareViewModel.dispose();
    _favouritesViewModel.dispose();
    _visitRemindersViewModel.dispose();
    _savedSearchesViewModel.dispose();
    _notificationsViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HomeFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
      routerConfig: _router,
      builder: (context, child) => AppMaintenanceBanner(
        viewModel: widget.appMaintenanceViewModel,
        child: child!,
      ),
    );
  }
}
