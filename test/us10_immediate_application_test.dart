import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/rental_application.dart';

void main() {
  test('reserved immediate application cannot be changed', () {
    final submittedAt = DateTime(2026, 10, 15);
    final application = RentalApplication.fromMap('application-1', {
      'userId': 'user-1',
      'apartmentId': 'apartment-1',
      'apartmentTitle': 'Sunny apartment',
      'fullName': 'Renter Example',
      'phone': '+41 79 123 45 67',
      'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
      'occupants': 1,
      'message': '',
      'applicationType': 'immediate',
      'status': 'reserved',
      'submittedAt': Timestamp.fromDate(submittedAt),
    });

    expect(application.type, ApplicationType.immediate);
    expect(application.status, ApplicationStatus.reserved);
    expect(application.canChange(submittedAt.add(const Duration(days: 1))),
        isFalse);
  });

  test('applications stored before immediate apply are normal', () {
    final application = RentalApplication.fromMap('application-1', {
      'userId': 'user-1',
      'apartmentId': 'apartment-1',
      'apartmentTitle': 'Sunny apartment',
      'fullName': 'Renter Example',
      'phone': '+41 79 123 45 67',
      'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
      'occupants': 1,
      'message': '',
      'status': 'submitted',
      'submittedAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
    });

    expect(application.type, ApplicationType.normal);
  });
}
