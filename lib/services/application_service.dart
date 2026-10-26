import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../models/app_user.dart';
import '../models/document_upload.dart';
import 'document_exception.dart';

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

  /// US 10: an immediate application is only submitted, like a normal one.
  /// The apartment is never reserved here and its availability is unchanged.
  Future<void> submit(
    Apartment apartment,
    ApplicationDetails details, {
    List<String> documentIds = const [],
    String? submissionId,
    ApplicationType type = ApplicationType.normal,
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
        'applicationType': type.name,
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
      // US 18.2: the apartment's owner is notified in the same write.
      final ownerId = apartment.ownerId;
      if (ownerId != null && ownerId != uid) {
        final title = 'New application: ${apartment.title}';
        tx.set(_db.collection('notifications').doc(), {
          'userId': ownerId,
          'type': 'newApplication',
          // firestore.rules accept titles of at most 120 characters.
          'title': title.length <= 120 ? title : '${title.substring(0, 119)}…',
          'body': '${details.fullName.trim()} applied for your apartment.',
          'createdAt': Timestamp.now(),
          'isRead': false,
          'applicationId': ref.id,
        });
      }
    }, timeout: const Duration(seconds: 20));
  }

  String newSubmissionId() => _collection.doc().id;

  Future<void> update(String id, ApplicationDetails details) {
    return _collection.doc(id).update({
      ...details.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// US 16: the applications received for the owner's or manager's
  /// apartments, newest first. Queried 5 apartments at a time, so
  /// firestore.rules can check that the user manages each apartment.
  Future<List<RentalApplication>> getApplicationsForApartments(
    List<String> apartmentIds,
  ) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < apartmentIds.length; i += 5) {
      final snapshot = await _collection
          .where('apartmentId', whereIn: apartmentIds.skip(i).take(5).toList())
          .get();
      docs.addAll(snapshot.docs);
    }
    return _toSortedList(docs);
  }

  /// US 16: the owner or manager moves the application to its next status.
  /// The applicant is notified in the same batch: both are saved, or neither.
  /// With [availability], the apartment changes in the same batch too:
  /// Reserved (In review) or Unavailable (Accepted) for this application,
  /// or Available again when it no longer holds it.
  Future<void> review(
    RentalApplication application,
    ApplicationStatus status, {
    ApartmentAvailability? availability,
  }) {
    final title = 'Application update: ${application.apartmentTitle}';
    final batch = _db.batch();
    batch.update(_collection.doc(application.id), {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (availability != null) {
      _updateAvailability(batch, application, availability);
    }
    batch.set(_db.collection('notifications').doc(), {
      'userId': application.userId,
      'type': 'applicationStatus',
      // firestore.rules accept titles of at most 120 characters.
      'title': title.length <= 120 ? title : '${title.substring(0, 119)}…',
      'body': 'Your application is now: ${status.label}.',
      'createdAt': Timestamp.now(),
      'isRead': false,
      'applicationId': application.id,
    });
    return batch.commit();
  }

  /// With [releaseApartment], the apartment this application reserved
  /// becomes Available again in the same batch.
  Future<void> withdraw(
    RentalApplication application, {
    bool releaseApartment = false,
  }) {
    final batch = _db.batch();
    batch.update(_collection.doc(application.id), {
      'status': ApplicationStatus.withdrawn.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (releaseApartment) {
      _updateAvailability(batch, application, ApartmentAvailability.available);
    }
    return batch.commit();
  }

  void _updateAvailability(
    WriteBatch batch,
    RentalApplication application,
    ApartmentAvailability availability,
  ) {
    batch.update(_db.collection('apartments').doc(application.apartmentId), {
      'availability': availability.name,
      'applicationId': availability == ApartmentAvailability.available
          ? FieldValue.delete()
          : application.id,
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
