import 'package:appartment_app_group_2/features/applications/data/application_repository.dart';
import 'package:appartment_app_group_2/features/applications/data/firebase_application_repository.dart';
import 'package:appartment_app_group_2/features/applications/models/rental_application.dart';
import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/application_fixtures.dart';
import '../../fakes/fake_auth_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late FirebaseApplicationRepository repository;
  final fails = throwsA(isA<ApplicationException>());

  FirebaseApplicationRepository repositoryAt(DateTime now) =>
      FirebaseApplicationRepository(
        firestore: firestore,
        authRepository: auth,
        clock: () => now,
      );

  Future<RentalApplication?> stored(String id) =>
      repository.watchApplication(id).first;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = signedInApplicant();
    repository = FirebaseApplicationRepository(
      firestore: firestore,
      authRepository: auth,
    );
  });

  group('submit', () {
    test(
      'stores the application as submitted for the signed-in user',
      () async {
        await repository.submit(
          id: 'a1',
          apartmentId: '1',
          apartmentTitle: 'Bright apartment',
          details: details(message: '  Non-smoker  '),
        );

        final data =
            (await firestore.collection('applications').doc('a1').get())
                .data()!;
        expect(data['userId'], 'applicant');
        expect(data['apartmentId'], '1');
        expect(data['status'], 'submitted');
        expect(data['message'], 'Non-smoker');
        expect(data.keys, containsAll(['submittedAt', 'updatedAt']));
      },
    );

    test('a retry with the same ID confirms instead of duplicating', () async {
      Future<void> submit() => repository.submit(
        id: 'a1',
        apartmentId: '1',
        apartmentTitle: 'Bright apartment',
        details: details(),
      );
      await submit();
      await submit();

      final all = await firestore.collection('applications').get();
      expect(all.docs, hasLength(1));
    });

    test('rejects a second open application for the same apartment', () async {
      await seedApplication(firestore, id: 'existing');

      await expectLater(
        repository.submit(
          id: 'a2',
          apartmentId: '1',
          apartmentTitle: 'Bright apartment',
          details: details(),
        ),
        fails,
      );
    });

    test('allows applying again after withdrawing', () async {
      await seedApplication(
        firestore,
        id: 'old',
        status: ApplicationStatus.withdrawn,
      );

      await repository.submit(
        id: 'new',
        apartmentId: '1',
        apartmentTitle: 'Bright apartment',
        details: details(),
      );
      expect(await stored('new'), isNotNull);
    });

    test('rejects invalid details and unverified users', () async {
      await expectLater(
        repository.submit(
          id: 'a1',
          apartmentId: '1',
          apartmentTitle: 'Bright apartment',
          details: details(daysAhead: -1),
        ),
        fails,
      );

      auth.currentUser = const AppUser(
        id: 'applicant',
        email: 'anna@hevs.ch',
        emailVerified: false,
      );
      await expectLater(
        repository.submit(
          id: 'a1',
          apartmentId: '1',
          apartmentTitle: 'Bright apartment',
          details: details(),
        ),
        fails,
      );
    });
  });

  group('track', () {
    test('lists only my applications, newest first', () async {
      await seedApplication(
        firestore,
        id: 'older',
        submittedAgo: const Duration(days: 3),
      );
      await seedApplication(firestore, id: 'newer', apartmentId: '2');
      await seedApplication(firestore, id: 'theirs', userId: 'someone-else');

      final mine = await repository.watchMyApplications().first;
      expect(mine.map((a) => a.id), ['newer', 'older']);
    });

    test('hides applications of other users', () async {
      await seedApplication(firestore, id: 'theirs', userId: 'someone-else');

      expect(await stored('theirs'), isNull);
    });
  });

  group('edit within 5 days', () {
    test('updates the details', () async {
      await seedApplication(firestore, id: 'a1');

      await repository.update('a1', details(phone: '+41 27 606 85 11'));

      expect((await stored('a1'))!.details.phone, '+41 27 606 85 11');
    });

    test('is refused after 5 days', () async {
      await seedApplication(firestore, id: 'a1');
      // The application was submitted 1 day ago; 5 more days later the
      // window has closed.
      repository = repositoryAt(DateTime.now().add(const Duration(days: 5)));

      await expectLater(repository.update('a1', details()), fails);
    });

    test('is refused once the advertiser decided', () async {
      await seedApplication(
        firestore,
        id: 'a1',
        status: ApplicationStatus.accepted,
      );

      await expectLater(repository.update('a1', details()), fails);
    });

    test('is refused for another user\'s application', () async {
      await seedApplication(firestore, id: 'a1', userId: 'someone-else');

      await expectLater(repository.update('a1', details()), fails);
    });
  });

  group('withdraw within 5 days', () {
    test('sets the status to withdrawn', () async {
      await seedApplication(firestore, id: 'a1');

      await repository.withdraw('a1');

      expect((await stored('a1'))!.status, ApplicationStatus.withdrawn);
    });

    test('is refused after 5 days', () async {
      await seedApplication(
        firestore,
        id: 'a1',
        submittedAgo: const Duration(days: 6),
      );

      await expectLater(repository.withdraw('a1'), fails);
    });
  });
}
