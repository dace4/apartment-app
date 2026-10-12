import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';

/// US 16: applications are stored in the Firestore collection `applications`.
/// firestore.rules only lets users read and change their own applications,
/// and only within 5 days.
class ApplicationService {
  final _collection = FirebaseFirestore.instance.collection('applications');

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  /// The user's applications, newest first, updated live.
  Stream<List<RentalApplication>> watchMyApplications() {
    return _collection
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) => _toSortedList(snapshot.docs));
  }

  /// The user's applications, read once.
  Future<List<RentalApplication>> getMyApplications() async {
    final snapshot = await _collection
        .where('userId', isEqualTo: _userId)
        .get();
    return _toSortedList(snapshot.docs);
  }

  /// One application, updated live. Emits null when it does not exist.
  Stream<RentalApplication?> watchApplication(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RentalApplication.fromMap(doc.id, doc.data()!);
    });
  }

  /// One application, read once. Returns null when it does not exist.
  Future<RentalApplication?> getApplication(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return RentalApplication.fromMap(doc.id, doc.data()!);
  }

  Future<void> submit(Apartment apartment, ApplicationDetails details) {
    return _collection.add({
      'userId': _userId,
      'apartmentId': apartment.id,
      'apartmentTitle': apartment.title,
      ...details.toMap(),
      'status': ApplicationStatus.submitted.name,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, ApplicationDetails details) {
    return _collection.doc(id).update({
      ...details.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> withdraw(String id) {
    return _collection.doc(id).update({
      'status': ApplicationStatus.withdrawn.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Sorted here instead of with orderBy, so no Firestore index is needed.
  List<RentalApplication> _toSortedList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => RentalApplication.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }
}
