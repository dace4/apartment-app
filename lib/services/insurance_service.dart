import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/insurance_coverage.dart';
import '../models/insurance_request.dart';
import 'insurance_exception.dart';

/// US-19: the insurance coverage catalogue (`insuranceCoverages`, read-only)
/// and the renters' requests to agents (`insuranceRequests`). firestore.rules
/// only let renters read the catalogue, send requests in their own name and
/// read their own requests.
class InsuranceService {
  InsuranceService({
    FirebaseFirestore? firestore,
    AppUser? Function()? currentUser,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore _db;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _coverages =>
      _db.collection('insuranceCoverages');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('insuranceRequests');

  static AppUser? _firebaseUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? null
        : AppUser(
            id: user.uid,
            email: user.email ?? '',
            emailVerified: user.emailVerified,
          );
  }

  AppUser get _user {
    final user = _currentUser();
    if (user == null || !user.emailVerified) {
      throw const InsuranceException(
        'Log in with a verified email to contact an agent.',
      );
    }
    return user;
  }

  /// The catalogue, in its `order`.
  Future<List<InsuranceCoverage>> getCoverages() async {
    final snapshot = await _coverages.get();
    return snapshot.docs
        .map((doc) => InsuranceCoverage.fromMap(doc.id, doc.data()))
        .toList()
      // Sorted here instead of with orderBy, so no index is needed.
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Returns null when no coverage has this id.
  Future<InsuranceCoverage?> getCoverage(String id) async {
    final doc = await _coverages.doc(id).get();
    if (!doc.exists) return null;
    return InsuranceCoverage.fromMap(doc.id, doc.data()!);
  }

  /// The user's requests, newest first, updated live.
  Stream<List<InsuranceRequest>> watchMyRequests() => _requests
      .where('renterId', isEqualTo: _user.id)
      .snapshots()
      .map((snapshot) {
        final requests = snapshot.docs
            .map((doc) => InsuranceRequest.fromMap(doc.id, doc.data()))
            .toList();
        // A request just sent has no server time yet: show it first.
        final latest = DateTime(9999);
        return requests..sort(
          (a, b) => (b.createdAt ?? latest).compareTo(a.createdAt ?? latest),
        );
      });

  /// Stores the request for the coverage's agent and returns its ID, the
  /// reference shown to the renter.
  Future<String> sendRequest({
    required InsuranceCoverage coverage,
    required ContactMethod contactMethod,
    required String phone,
    required String message,
  }) async {
    final user = _user;
    final doc = _requests.doc();
    try {
      await doc.set({
        'coverageId': coverage.id,
        'coverageName': coverage.name,
        'agentName': coverage.agentName,
        'agentEmail': coverage.agentEmail,
        'renterId': user.id,
        'renterEmail': user.email,
        'contactMethod': contactMethod.name,
        // Only kept when the renter wants to be called.
        'phone': contactMethod == ContactMethod.phone ? phone.trim() : '',
        'message': message.trim(),
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InsuranceException(
        e.code == 'permission-denied'
            ? 'Your request could not be delivered. Reload the coverage and '
                  'try again.'
            : 'Could not send your request. Check your connection and try '
                  'again.',
      );
    }
    return doc.id;
  }
}
