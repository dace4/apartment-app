import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import '../models/maintenance_request.dart';

/// US-17: maintenance requests are stored in the Firestore collection
/// `maintenanceRequests`. firestore.rules only lets users read and change
/// their own requests, and only before the service starts.
class MaintenanceService {
  final _collection = FirebaseFirestore.instance.collection(
    'maintenanceRequests',
  );

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  /// The user's requests, soonest first, updated live.
  Stream<List<MaintenanceRequest>> watchMyRequests() {
    return _collection
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) => _toSortedList(snapshot.docs));
  }

  /// The user's requests, read once.
  Future<List<MaintenanceRequest>> getMyRequests() async {
    final snapshot = await _collection
        .where('userId', isEqualTo: _userId)
        .get();
    return _toSortedList(snapshot.docs);
  }

  /// One request, updated live. Emits null when it does not exist.
  Stream<MaintenanceRequest?> watchRequest(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MaintenanceRequest.fromMap(doc.id, doc.data()!);
    });
  }

  /// One request, read once. Returns null when it does not exist.
  Future<MaintenanceRequest?> getRequest(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return MaintenanceRequest.fromMap(doc.id, doc.data()!);
  }

  /// Returns the ID of the new request.
  Future<String> book({
    required Apartment apartment,
    required MaintenanceCategory category,
    required String description,
    required DateTime slotStart,
    required Set<MaintenanceReminder> reminders,
  }) async {
    final doc = await _collection.add({
      'userId': _userId,
      'apartmentId': apartment.id,
      'apartmentTitle': apartment.title,
      'category': category.name,
      'description': description.trim(),
      'slotStart': Timestamp.fromDate(slotStart),
      'reminders': _reminderNames(reminders),
      'status': MaintenanceStatus.scheduled.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> reschedule(
    String id,
    DateTime slotStart,
    Set<MaintenanceReminder> reminders,
  ) {
    return _collection.doc(id).update({
      'slotStart': Timestamp.fromDate(slotStart),
      'reminders': _reminderNames(reminders),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String id) {
    return _collection.doc(id).update({
      'status': MaintenanceStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> _reminderNames(Set<MaintenanceReminder> reminders) =>
      reminders.map((reminder) => reminder.name).toList();

  // Sorted here instead of with orderBy, so no Firestore index is needed.
  List<MaintenanceRequest> _toSortedList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => MaintenanceRequest.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
  }
}
