import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'view_models/apartments_view_model.dart';
import 'view_models/auth_view_model.dart';

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

  late final GoRouter _router = createAppRouter(
    authViewModel: _authViewModel,
    apartmentsViewModel: _apartmentsViewModel,
  );

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    _apartmentsViewModel.dispose();
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
