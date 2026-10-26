import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/rental_application.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/services/application_service.dart';
import 'package:appartment_app_group_2/services/message_service.dart';
import 'package:appartment_app_group_2/view_models/inbox_view_model.dart';
import 'package:appartment_app_group_2/view_models/review_application_view_model.dart';

const owner = AppUser(
  id: 'owner',
  email: 'owner@example.test',
  emailVerified: true,
  roles: {UserRole.homeowner},
);

Map<String, dynamic> apartmentData(String ownerId) => {
  'title': 'Flat',
  'ownerId': ownerId,
  'address': 'Rue 1',
  'city': 'Sion',
  'listingType': 'rent',
  'price': 1500,
  'rooms': 3,
  'surface': 70,
  'description': '',
  'availability': 'available',
  'amenities': <String>[],
};

Map<String, dynamic> applicationData(String apartmentId, String status) => {
  'userId': 'tenant',
  'apartmentId': apartmentId,
  'apartmentTitle': 'Flat $apartmentId',
  'fullName': 'Tenant',
  'phone': '123456789',
  'moveInDate': Timestamp.fromDate(DateTime(2026, 12, 1)),
  'occupants': 1,
  'message': '',
  'applicationType': 'normal',
  'status': status,
  'submittedAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
};

void main() {
  group('US 16 statuses', () {
    test('labels match the review steps', () {
      expect(ApplicationStatus.submitted.label, 'Applied');
      expect(ApplicationStatus.received.label, 'Received');
      expect(ApplicationStatus.underReview.label, 'In review');
      expect(ApplicationStatus.accepted.label, 'Accepted');
      expect(ApplicationStatus.rejected.label, 'Rejected');
    });

    test('transitions: Applied → Received → In review → decision', () {
      expect(ApplicationStatus.submitted.reviewSteps, [
        ApplicationStatus.received,
      ]);
      expect(ApplicationStatus.received.reviewSteps, [
        ApplicationStatus.underReview,
      ]);
      expect(ApplicationStatus.underReview.reviewSteps, [
        ApplicationStatus.accepted,
        ApplicationStatus.rejected,
      ]);
      for (final done in [
        ApplicationStatus.accepted,
        ApplicationStatus.rejected,
        ApplicationStatus.withdrawn,
        ApplicationStatus.reserved,
      ]) {
        expect(done.reviewSteps, isEmpty);
      }
    });

    test('the five-day edit/withdraw rule still applies while reviewed', () {
      final received = RentalApplication.fromMap(
        'a1',
        applicationData('apt', 'received'),
      );
      final submittedAt = received.submittedAt;

      expect(
        received.canChange(submittedAt.add(const Duration(days: 4))),
        isTrue,
      );
      expect(
        received.canChange(submittedAt.add(const Duration(days: 6))),
        isFalse,
      );

      final accepted = RentalApplication.fromMap(
        'a2',
        applicationData('apt', 'accepted'),
      );
      expect(accepted.canChange(submittedAt), isFalse);
    });
  });

  group('US 16 review', () {
    late FakeFirebaseFirestore db;
    late ApplicationService applications;

    setUp(() async {
      db = FakeFirebaseFirestore();
      applications = ApplicationService(
        firestore: db,
        currentUser: () => owner,
      );
      await db.collection('apartments').doc('mine').set(apartmentData('owner'));
      await db.collection('apartments').doc('other').set(apartmentData('x'));
      await db
          .collection('applications')
          .doc('a1')
          .set(applicationData('mine', 'submitted'));
      await db
          .collection('applications')
          .doc('a2')
          .set(applicationData('other', 'submitted'));
    });

    test(
      'the inbox only lists applications for the owner\'s apartments',
      () async {
        final inbox = InboxViewModel(
          () => owner,
          apartmentService: ApartmentService(firestore: db),
          applicationService: applications,
          messageService: MessageService(firestore: db),
        );

        await inbox.fetchInbox();

        expect(inbox.applications.map((a) => a.id), ['a1']);
      },
    );

    test('a user without a management role has no inbox', () async {
      final inbox = InboxViewModel(
        () => const AppUser(
          id: 'tenant',
          email: 'tenant@example.test',
          emailVerified: true,
          roles: {UserRole.renter},
        ),
        apartmentService: ApartmentService(firestore: db),
        applicationService: applications,
        messageService: MessageService(firestore: db),
      );

      await inbox.fetchInbox();

      expect(inbox.errorMessage, isNotNull);
      expect(inbox.applications, isEmpty);
    });

    test(
      'each review step saves the status and notifies the applicant',
      () async {
        final review = ReviewApplicationViewModel(
          service: applications,
          apartmentService: ApartmentService(firestore: db),
        );
        await review.fetchApplication('a1');

        // Skipping a step is ignored.
        await review.review(ApplicationStatus.accepted);
        expect(review.application!.status, ApplicationStatus.submitted);

        await review.review(ApplicationStatus.received);
        await review.review(ApplicationStatus.underReview);
        await review.review(ApplicationStatus.accepted);

        expect(review.application!.status, ApplicationStatus.accepted);
        expect(review.nextSteps, isEmpty);

        final notifications = (await db.collection('notifications').get()).docs
            .map((doc) => doc.data())
            .toList();
        expect(notifications, hasLength(3));
        expect(notifications.every((n) => n['userId'] == 'tenant'), isTrue);
        expect(
          notifications.every((n) => n['type'] == 'applicationStatus'),
          isTrue,
        );
        expect(
          notifications.map((n) => n['body']),
          contains('Your application is now: Accepted.'),
        );
      },
    );
  });

  group('Availability follows the review', () {
    late FakeFirebaseFirestore db;
    late ApplicationService applications;

    ReviewApplicationViewModel reviewer() => ReviewApplicationViewModel(
      service: applications,
      apartmentService: ApartmentService(firestore: db),
    );

    Future<Map<String, dynamic>> flat() async =>
        (await db.collection('apartments').doc('mine').get()).data()!;

    setUp(() async {
      db = FakeFirebaseFirestore();
      applications = ApplicationService(
        firestore: db,
        currentUser: () => owner,
      );
      await db.collection('apartments').doc('mine').set(apartmentData('owner'));
      for (final (id, status) in [
        ('a1', 'received'),
        ('a2', 'received'),
        ('a3', 'submitted'),
      ]) {
        await db
            .collection('applications')
            .doc(id)
            .set(applicationData('mine', status));
      }
    });

    test('In review reserves it, and only one review at a time', () async {
      final first = reviewer();
      await first.fetchApplication('a1');
      expect(first.nextSteps, [ApplicationStatus.underReview]);
      await first.review(ApplicationStatus.underReview);
      expect(await flat(), containsPair('availability', 'reserved'));
      expect(await flat(), containsPair('applicationId', 'a1'));
      expect(first.apartment!.availability, ApartmentAvailability.reserved);

      final second = reviewer();
      await second.fetchApplication('a2');
      expect(second.nextSteps, isEmpty);
      expect(second.stepNotice, contains('Another application is in review'));
    });

    test('Accepted makes it unavailable and rejects the others', () async {
      final review = reviewer();
      await review.fetchApplication('a1');
      await review.review(ApplicationStatus.underReview);
      await review.review(ApplicationStatus.accepted);

      expect(await flat(), containsPair('availability', 'unavailable'));
      expect(await flat(), containsPair('applicationId', 'a1'));
      for (final id in ['a2', 'a3']) {
        final other = await applications.getApplication(id);
        expect(other!.status, ApplicationStatus.rejected, reason: id);
      }
      final bodies = (await db.collection('notifications').get()).docs.map(
        (doc) => doc['body'],
      );
      expect(
        bodies.where((b) => b == 'Your application is now: Rejected.'),
        hasLength(2),
      );
    });

    test('rejecting the review frees the apartment', () async {
      final review = reviewer();
      await review.fetchApplication('a1');
      await review.review(ApplicationStatus.underReview);
      await review.review(ApplicationStatus.rejected);

      expect(await flat(), containsPair('availability', 'available'));
      expect((await flat()).containsKey('applicationId'), isFalse);
      // The others are untouched and one of them can now be reviewed.
      final next = reviewer();
      await next.fetchApplication('a2');
      expect(next.nextSteps, [ApplicationStatus.underReview]);
    });

    test('withdrawing a review frees the apartment', () async {
      final review = reviewer();
      await review.fetchApplication('a1');
      await review.review(ApplicationStatus.underReview);

      await applications.withdraw(
        (await applications.getApplication('a1'))!,
        releaseApartment: true,
      );
      expect(await flat(), containsPair('availability', 'available'));
      expect((await flat()).containsKey('applicationId'), isFalse);
    });

    test('an unavailable apartment only lets open ones be rejected', () async {
      await db.collection('apartments').doc('mine').update({
        'availability': 'unavailable',
      });
      final review = reviewer();
      await review.fetchApplication('a2');
      expect(review.nextSteps, [ApplicationStatus.rejected]);
      expect(review.stepNotice, 'This apartment is no longer available.');
    });
  });
}
