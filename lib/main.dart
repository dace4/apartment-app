import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Firebase must be initialised before any Firebase service is used.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(HomeFlowApp(authRepository: FirebaseAuthRepository()));
}
