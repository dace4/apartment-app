import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_maintenance.dart';

/// The app maintenance window: one document, `appConfig/maintenance`.
/// Everyone can read it (the banner is shown before log in); only admins
/// can change it (see firestore.rules).
class AppMaintenanceService {
  AppMaintenanceService({this._firestore});
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('appConfig').doc('maintenance');

  /// Live window, or null when none is scheduled.
  Stream<AppMaintenance?> watch() => _doc.snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : AppMaintenance.fromMap(data);
  });

  /// Replaces any previous window.
  Future<void> schedule(AppMaintenance maintenance) => _doc.set({
    ...maintenance.toMap(),
    'updatedBy': FirebaseAuth.instance.currentUser!.uid,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Ends the running window, or cancels the planned one.
  Future<void> endNow() => _doc.delete();
}
