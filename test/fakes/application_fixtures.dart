import 'package:appartment_app_group_2/features/applications/models/rental_application.dart';
import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'fake_auth_repository.dart';

const applicant = AppUser(
  id: 'applicant',
  email: 'anna@hevs.ch',
  emailVerified: true,
);

FakeAuthRepository signedInApplicant() =>
    FakeAuthRepository(currentUser: applicant);

/// Valid form input, moving in [daysAhead] days from today.
ApplicationDetails details({
  String fullName = 'Anna Muster',
  String phone = '+41 79 123 45 67',
  int occupants = 2,
  int daysAhead = 30,
  String message = '',
}) {
  final now = DateTime.now();
  return ApplicationDetails(
    fullName: fullName,
    phone: phone,
    moveInDate: DateTime(now.year, now.month, now.day + daysAhead),
    occupants: occupants,
    message: message,
  );
}

/// Stores an application directly, as the server would have saved it.
Future<void> seedApplication(
  FakeFirebaseFirestore firestore, {
  required String id,
  String userId = 'applicant',
  String apartmentId = '1',
  String apartmentTitle = 'Bright apartment near the old town',
  String phone = '+41 79 123 45 67',
  ApplicationStatus status = ApplicationStatus.submitted,
  Duration submittedAgo = const Duration(days: 1),
}) {
  final now = DateTime.now();
  return firestore.collection('applications').doc(id).set({
    'userId': userId,
    'apartmentId': apartmentId,
    'apartmentTitle': apartmentTitle,
    'fullName': 'Anna Muster',
    'phone': phone,
    'moveInDate': Timestamp.fromDate(
      DateTime(now.year, now.month, now.day + 30),
    ),
    'occupants': 2,
    'message': '',
    'status': status.name,
    'submittedAt': Timestamp.fromDate(now.subtract(submittedAgo)),
    'updatedAt': Timestamp.fromDate(now.subtract(submittedAgo)),
  });
}
