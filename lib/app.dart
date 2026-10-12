import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'view_models/auth_view_model.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({super.key});

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  // Created once for the whole app (see ARCHITECTURE.md §4).
  final _authViewModel = AuthViewModel();
  late final GoRouter _router = createAppRouter(authViewModel: _authViewModel);

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
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
