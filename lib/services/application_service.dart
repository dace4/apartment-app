import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../models/app_user.dart';
import '../models/document_upload.dart';
import 'document_exception.dart';
import 'reservation_exceptions.dart';

/// US 16: applications are stored in the Firestore collection `applications`.
/// firestore.rules only lets users read and change their own applications,
/// and only within 5 days.
class ApplicationService {
  ApplicationService({
    FirebaseFirestore? firestore,
    AppUser? Function()? currentUser,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore _db;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('applications');

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

  String get _userId {
    final user = _currentUser();
    if (user == null || !user.emailVerified) {
      throw const DocumentException(
        'Log in with a verified email to manage applications.',
      );
    }
    return user.id;
  }

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

  DocumentReference<Map<String, dynamic>> _apartmentRef(String apartmentId) =>
      _db.collection('apartments').doc(apartmentId);

  Map<String, Object> _reservationFields(String applicationId) => {
    'availability': ApartmentAvailability.reserved.name,
    'reservationApplicationId': applicationId,
  };

  void _ensureAvailable(DocumentSnapshot<Map<String, dynamic>> apartment) {
    if (apartment.data()?['availability'] !=
        ApartmentAvailability.available.name) {
      throw const ApartmentUnavailableException();
    }
  }

  Future<void> submit(
    Apartment apartment,
    ApplicationDetails details, {
    List<String> documentIds = const [],
    String? submissionId,
  }) async {
    // US-15: the application and first-use markers commit together.
    if (documentIds.length > DocumentUpload.maxAttachments ||
        documentIds.toSet().length != documentIds.length) {
      throw const DocumentException(
        'Select at most five different attachments.',
      );
    }
    final uid = _userId;
    final ref = submissionId == null
        ? _collection.doc()
        : _collection.doc(submissionId);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        if (existing.data()!['userId'] != uid) {
          throw const DocumentException('This application is unavailable.');
        }
        return;
      }
      final attachments = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in documentIds) {
        final file = await tx.get(_db.collection('uploadedDocuments').doc(id));
        if (!file.exists || file.data()!['userId'] != uid) {
          throw const DocumentException(
            'An attachment is no longer available. Select your documents again.',
          );
        }
        attachments.add(file);
      }
      tx.set(ref, {
        'userId': uid,
        'apartmentId': apartment.id,
        'apartmentTitle': apartment.title,
        ...details.toMap(),
        'applicationType': ApplicationType.normal.name,
        'status': ApplicationStatus.submitted.name,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'documentIds': documentIds,
      });
      for (final file in attachments) {
        if (file.data()!['firstApplicationId'] == null) {
          tx.update(file.reference, {'firstApplicationId': ref.id});
        }
      }
    }, timeout: const Duration(seconds: 20));
  }

  String newSubmissionId() => _collection.doc().id;

  /// Creates the application and reserves its apartment in one atomic
  /// transaction. Throws [ApartmentUnavailableException] if it was just taken.
  Future<void> submitImmediately(
    Apartment apartment,
    ApplicationDetails details,
  ) async {
    final application = _collection.doc();
    final apartmentRef = _apartmentRef(apartment.id);

    await _db.runTransaction((transaction) async {
      // Transactions require all reads before any writes.
      _ensureAvailable(await transaction.get(apartmentRef));

      transaction.set(application, {
        'userId': _userId,
        'apartmentId': apartment.id,
        'apartmentTitle': apartment.title,
        ...details.toMap(),
        'applicationType': ApplicationType.immediate.name,
        'status': ApplicationStatus.reserved.name,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(apartmentRef, _reservationFields(application.id));
    });
  }

  /// Promotes the user's still-changeable normal application to a reservation.
  /// Throws [ApartmentUnavailableException] if the apartment was just taken.
  Future<void> reserveImmediately(RentalApplication application) async {
    if (!application.status.isOpen) {
      throw StateError('Only an open application can be promoted.');
    }
    final apartmentRef = _apartmentRef(application.apartmentId);

    await _db.runTransaction((transaction) async {
      _ensureAvailable(await transaction.get(apartmentRef));

      transaction.update(_collection.doc(application.id), {
        'status': ApplicationStatus.reserved.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(apartmentRef, _reservationFields(application.id));
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
