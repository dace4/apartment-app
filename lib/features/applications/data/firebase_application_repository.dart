import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/auth_repository.dart';
import '../models/rental_application.dart';
import '../utils/application_validators.dart';
import 'application_repository.dart';

/// US 16: stores applications in the Firestore collection `applications`.
/// firestore.rules limits every document to its owner and enforces the
/// 5-day edit and withdraw window on the server.
class FirebaseApplicationRepository extends ApplicationRepository {
  FirebaseApplicationRepository({
    required this.firestore,
    required this.authRepository,
    this.refreshSession,
    this.clock = DateTime.now,
    this.writeTimeout = const Duration(seconds: 15),
  });

  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final Future<void> Function()? refreshSession;
  final DateTime Function() clock;
  final Duration writeTimeout;

  // Reads that decide whether a write may happen must come from the server.
  // The local cache can contain queued offline writes that never arrived.
  static const _fromServer = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> get _applications =>
      firestore.collection('applications');

  @override
  String createApplicationId() => _applications.doc().id;

  @override
  Stream<List<RentalApplication>> watchMyApplications() async* {
    final user = authRepository.currentUser;
    if (user == null) {
      yield const [];
      return;
    }
    await _refreshForReading();
    // Sorted here instead of with orderBy, so no composite index is needed.
    yield* _applications
        .where('userId', isEqualTo: user.id)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(_fromDocument)
                  .whereType<RentalApplication>()
                  .toList()
                ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt)),
        );
  }

  @override
  Stream<RentalApplication?> watchApplication(String id) async* {
    final user = authRepository.currentUser;
    if (user == null) {
      yield null;
      return;
    }
    await _refreshForReading();
    yield* _applications.doc(id).snapshots().map((document) {
      final application = _fromDocument(document);
      return application?.userId == user.id ? application : null;
    });
  }

  @override
  Future<RentalApplication?> fetchApplication(String id) async {
    final user = authRepository.currentUser;
    if (user == null) return null;
    await _refreshForReading();
    // A normal read: it falls back to the cache offline. Saving checks the
    // server copy again before writing.
    final application = _fromDocument(await _applications.doc(id).get());
    return application?.userId == user.id ? application : null;
  }

  @override
  Future<void> submit({
    required String id,
    required String apartmentId,
    required String apartmentTitle,
    required ApplicationDetails details,
  }) async {
    final user = _verifiedUser();
    _validate(details, checkMoveInDate: true);
    final reference = _applications.doc(id);

    await _run(
      denied: 'You are not allowed to submit this application.',
      () async {
        await refreshSession?.call();
        // A previous attempt may have been stored even though its response
        // was lost. Confirm it instead of creating a second application.
        final existing = await reference.get(_fromServer);
        if (existing.exists) {
          final data = existing.data()!;
          if (data['userId'] == user.id && data['apartmentId'] == apartmentId) {
            return;
          }
          throw const ApplicationException(
            'This application reference is already used. Please try again.',
          );
        }

        final mine = await _applications
            .where('userId', isEqualTo: user.id)
            .get(_fromServer);
        final alreadyApplied = mine.docs.any(
          (document) =>
              document.data()['apartmentId'] == apartmentId &&
              ApplicationStatus.fromName(document.data()['status']).isOpen,
        );
        if (alreadyApplied) {
          throw const ApplicationException(
            'You already have an open application for this apartment.',
          );
        }

        await reference
            .set({
              'userId': user.id,
              'apartmentId': apartmentId,
              'apartmentTitle': apartmentTitle,
              ..._detailsToFirestore(details),
              'status': ApplicationStatus.submitted.name,
              'submittedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(writeTimeout);
      },
    );
  }

  @override
  Future<void> update(String id, ApplicationDetails details) async {
    final user = _verifiedUser();
    final reference = _applications.doc(id);

    await _run(denied: _tooLate, () async {
      await refreshSession?.call();
      final current = await _changeableApplication(reference, user);
      // A move-in date kept from the original application may lie in the
      // past by now; only a newly chosen date must be today or later.
      _validate(
        details,
        checkMoveInDate:
            ApplicationValidators.dateOnly(details.moveInDate) !=
            ApplicationValidators.dateOnly(current.details.moveInDate),
      );
      await reference
          .update({
            ..._detailsToFirestore(details),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(writeTimeout);
    });
  }

  @override
  Future<void> withdraw(String id) async {
    final user = _verifiedUser();
    final reference = _applications.doc(id);

    await _run(denied: _tooLate, () async {
      await refreshSession?.call();
      await _changeableApplication(reference, user);
      await reference
          .update({
            'status': ApplicationStatus.withdrawn.name,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(writeTimeout);
    });
  }

  static const _tooLate =
      'This application can no longer be changed. Applications can only be '
      'edited or withdrawn within 5 days.';

  /// Loads the application from the server and checks that the user owns it
  /// and is still allowed to change it.
  Future<RentalApplication> _changeableApplication(
    DocumentReference<Map<String, dynamic>> reference,
    AppUser user,
  ) async {
    final application = _fromDocument(await reference.get(_fromServer));
    if (application == null || application.userId != user.id) {
      throw const ApplicationException('This application does not exist.');
    }
    if (!application.canChange(clock())) {
      throw const ApplicationException(_tooLate);
    }
    return application;
  }

  AppUser _verifiedUser() {
    final user = authRepository.currentUser;
    if (user == null || !user.emailVerified) {
      throw const ApplicationException(
        'Log in with a verified email to manage applications.',
      );
    }
    return user;
  }

  /// Checks the details again here, because a caller can bypass the form.
  void _validate(ApplicationDetails details, {required bool checkMoveInDate}) {
    final error =
        ApplicationValidators.fullName(details.fullName) ??
        ApplicationValidators.phone(details.phone) ??
        ApplicationValidators.occupants('${details.occupants}') ??
        ApplicationValidators.message(details.message) ??
        (checkMoveInDate
            ? ApplicationValidators.moveInDate(details.moveInDate, clock())
            : null);
    if (error != null) throw ApplicationException(error);
  }

  /// Reading works with the cached token when the refresh fails offline.
  Future<void> _refreshForReading() async {
    try {
      await refreshSession?.call();
    } on FirebaseException catch (error) {
      if (error.code != 'network-request-failed') rethrow;
    }
  }

  /// Runs a Firestore call and turns its errors into an
  /// [ApplicationException].
  Future<void> _run(
    Future<void> Function() action, {
    required String denied,
  }) async {
    try {
      await action();
    } on TimeoutException {
      // The write may still reach the server later. Retrying with the same
      // ID confirms it instead of creating a duplicate.
      throw const ApplicationException(
        'Could not confirm the change. Check your connection and try again.',
      );
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw ApplicationException(denied);
        case 'unauthenticated':
          throw const ApplicationException('Log in again and retry.');
        case 'unavailable':
        case 'network-request-failed':
        case 'deadline-exceeded':
          throw const ApplicationException(
            'No connection to the server. Check your connection and try again.',
          );
        default:
          throw const ApplicationException(
            'Something went wrong. Please try again.',
          );
      }
    }
  }

  static Map<String, dynamic> _detailsToFirestore(ApplicationDetails details) =>
      {
        'fullName': details.fullName.trim(),
        'phone': details.phone.trim(),
        'moveInDate': Timestamp.fromDate(
          ApplicationValidators.dateOnly(details.moveInDate),
        ),
        'occupants': details.occupants,
        'message': details.message.trim(),
      };

  /// Returns null for missing or malformed documents instead of throwing.
  RentalApplication? _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) return null;
    final userId = data['userId'];
    final apartmentId = data['apartmentId'];
    final moveInDate = data['moveInDate'];
    final occupants = data['occupants'];
    if (userId is! String ||
        apartmentId is! String ||
        moveInDate is! Timestamp ||
        occupants is! int) {
      return null;
    }
    final submittedAt = data['submittedAt'];

    return RentalApplication(
      id: document.id,
      userId: userId,
      apartmentId: apartmentId,
      apartmentTitle: data['apartmentTitle'] is String
          ? data['apartmentTitle'] as String
          : '',
      details: ApplicationDetails(
        fullName: data['fullName'] is String ? data['fullName'] as String : '',
        phone: data['phone'] is String ? data['phone'] as String : '',
        moveInDate: moveInDate.toDate(),
        occupants: occupants,
        message: data['message'] is String ? data['message'] as String : '',
      ),
      status: ApplicationStatus.fromName(data['status']),
      // The server timestamp is null until a local write is confirmed.
      submittedAt: submittedAt is Timestamp ? submittedAt.toDate() : clock(),
    );
  }
}
