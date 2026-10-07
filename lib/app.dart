import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/apartments/data/apartment_repository.dart';
import 'router/app_router.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({
    super.key,
    required this.authRepository,
    this.apartmentRepository = const ApartmentRepository(),
  });

  final AuthRepository authRepository;
  final ApartmentRepository apartmentRepository;

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  // Created once per app instance so it isn't rebuilt on every build.
  late final GoRouter _router = createAppRouter(
    authRepository: widget.authRepository,
    apartmentRepository: widget.apartmentRepository,
  );

  @override
  void dispose() {
    _router.dispose();
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
