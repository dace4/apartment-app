import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Firebase must be initialised before any Firebase service is used.
  WidgetsFlutterBinding.ensureInitialized();
  // US-15: document validation uses the PDF engine before building a viewer.
  await pdfrxFlutterInitialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const HomeFlowApp());
}
