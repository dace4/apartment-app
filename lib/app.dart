import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'view_models/apartments_view_model.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/compare_view_model.dart';
import 'view_models/favourites_view_model.dart';
import 'view_models/maintenance_reminders_view_model.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({super.key});

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  // ViewModels shared by several screens are created once, here
  // (see ARCHITECTURE.md §4).
  final _authViewModel = AuthViewModel();
  final _apartmentsViewModel = ApartmentsViewModel();
  final _compareViewModel = CompareViewModel();
  final _favouritesViewModel = FavouritesViewModel();
  // US-17: the in-app maintenance reminder shown on every tab.
  final _maintenanceRemindersViewModel = MaintenanceRemindersViewModel();

  late final GoRouter _router = createAppRouter(
    authViewModel: _authViewModel,
    apartmentsViewModel: _apartmentsViewModel,
    compareViewModel: _compareViewModel,
    favouritesViewModel: _favouritesViewModel,
    maintenanceRemindersViewModel: _maintenanceRemindersViewModel,
  );

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    _apartmentsViewModel.dispose();
    _compareViewModel.dispose();
    _favouritesViewModel.dispose();
    _maintenanceRemindersViewModel.dispose();
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
