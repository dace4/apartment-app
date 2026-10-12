import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'view_models/auth_view_model.dart';
import 'features/messages/data/firebase_contact_listing_repository.dart';
import 'features/messages/data/firebase_message_repository.dart';
import 'firebase_options.dart';
import 'shared/utils/refresh_verified_session.dart';

Future<void> main() async {
  // Firebase must be initialised before any Firebase service is used.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authViewModel = AuthViewModel();
  final firestore = FirebaseFirestore.instance;
  // US 12 uses Firestore only for advertiser contacts and messages. Browsing
  // continues to use the students' existing sample apartment repository.
  runApp(
    HomeFlowApp(
      authViewModel: authViewModel,
      contactListingRepository: FirebaseContactListingRepository(
        firestore,
        refreshSession: refreshVerifiedSession,
      ),
      messageRepository: FirebaseMessageRepository(
        firestore: firestore,
        authService: AuthService(),
        refreshSession: refreshVerifiedSession,
      ),
    ),
  );
}
