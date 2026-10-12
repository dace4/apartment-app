import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'view_models/auth_view_model.dart';
import 'features/messages/data/contact_listing_repository.dart';
import 'features/messages/data/message_repository.dart';
import 'router/app_router.dart';

class HomeFlowApp extends StatefulWidget {
  const HomeFlowApp({
    super.key,
    required this.authViewModel,
    this.contactListingRepository = const SampleContactListingRepository(),
    this.messageRepository = const UnconfiguredMessageRepository(),
  });

  final AuthViewModel authViewModel;
  final ContactListingRepository contactListingRepository;
  final MessageRepository messageRepository;

  @override
  State<HomeFlowApp> createState() => _HomeFlowAppState();
}

class _HomeFlowAppState extends State<HomeFlowApp> {
  // Created once per app instance so it isn't rebuilt on every build.
  late final GoRouter _router = createAppRouter(
    authViewModel: widget.authViewModel,
    contactListingRepository: widget.contactListingRepository,
    messageRepository: widget.messageRepository,
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
