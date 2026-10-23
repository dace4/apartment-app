import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/rental_application.dart';
import 'package:appartment_app_group_2/services/application_service.dart';
import 'package:appartment_app_group_2/services/document_exception.dart';
import 'package:appartment_app_group_2/utils/validators.dart';

const renter = AppUser(
  id: 'renter',
  email: 'renter@example.test',
  emailVerified: true,
);

const apartment = Apartment(
  id: 'apt',
  title: 'Sunny apartment',
  address: 'Rue 1',
  city: '1950 Sion',
  listingType: ListingType.rent,
  price: 1500,
  rooms: 3,
  surface: 70,
  imageUrl: '',
  description: '',
  availability: ApartmentAvailability.available,
);

ApplicationDetails details() => ApplicationDetails(
  fullName: 'Renter Example',
  phone: '+41 79 123 45 67',
  moveInDate: DateTime.now().add(const Duration(days: 30)),
  occupants: 1,
);

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
    expect(
      application.canChange(submittedAt.add(const Duration(days: 1))),
      isFalse,
    );
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

  group('US 10 submission only', () {
    late FakeFirebaseFirestore db;
    late ApplicationService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = ApplicationService(firestore: db, currentUser: () => renter);
      await db.collection('apartments').doc('apt').set({
        'availability': 'available',
      });
    });

    test('an immediate application is submitted, not reserved', () async {
      await service.submit(
        apartment,
        details(),
        submissionId: 'a1',
        type: ApplicationType.immediate,
      );

      final application = (await service.getApplication('a1'))!;
      expect(application.type, ApplicationType.immediate);
      expect(application.status, ApplicationStatus.submitted);
      expect(application.canChange(DateTime.now()), isTrue);

      // The apartment availability is unchanged.
      final stored = (await db.collection('apartments').doc('apt').get())
          .data()!;
      expect(stored, {'availability': 'available'});
    });

    test(
      'a retry with the same submission id stores one application',
      () async {
        for (var i = 0; i < 2; i++) {
          await service.submit(
            apartment,
            details(),
            submissionId: 'a1',
            type: ApplicationType.immediate,
          );
        }

        expect((await db.collection('applications').get()).docs, hasLength(1));
      },
    );

    test('attachments are linked; a missing one stores nothing', () async {
      await db.collection('uploadedDocuments').doc('doc').set({
        'userId': renter.id,
        'firstApplicationId': null,
      });

      await service.submit(
        apartment,
        details(),
        documentIds: ['doc'],
        submissionId: 'a1',
        type: ApplicationType.immediate,
      );
      expect((await service.getApplication('a1'))!.documentIds, ['doc']);

      await expectLater(
        service.submit(
          apartment,
          details(),
          documentIds: ['missing'],
          submissionId: 'a2',
          type: ApplicationType.immediate,
        ),
        throwsA(isA<DocumentException>()),
      );
      expect(await service.getApplication('a2'), isNull);
    });

    test('required fields are checked by the form validators', () {
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.phone(''), isNotNull);
      expect(Validators.occupants(''), isNotNull);
      expect(Validators.moveInDate(null), isNotNull);
      expect(Validators.fullName('Renter Example'), isNull);
    });
  });
}
