import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/apartments/data/apartment_repository.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/messages/data/firebase_contact_listing_repository.dart';
import 'features/messages/data/firebase_message_repository.dart';
import 'firebase_options.dart';
import 'shared/utils/refresh_verified_session.dart';

Future<void> main() async {
  // Firebase must be initialised before any Firebase service is used.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authRepository = FirebaseAuthRepository();
  const apartmentRepository = ApartmentRepository();
  final firestore = FirebaseFirestore.instance;
  // US 12 uses Firestore only for advertiser contacts and messages. Browsing
  // continues to use the students' existing sample apartment repository.
  runApp(
    HomeFlowApp(
      authRepository: authRepository,
      contactListingRepository: FirebaseContactListingRepository(
        firestore,
        apartmentRepository: apartmentRepository,
        refreshSession: refreshVerifiedSession,
      ),
      messageRepository: FirebaseMessageRepository(
        firestore: firestore,
        authRepository: authRepository,
        refreshSession: refreshVerifiedSession,
      ),
    ),
  );
}
