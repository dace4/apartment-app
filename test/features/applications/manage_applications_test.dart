import 'package:appartment_app_group_2/app.dart';
import 'package:appartment_app_group_2/features/apartments/data/apartment_repository.dart';
import 'package:appartment_app_group_2/features/apartments/widgets/apartment_card.dart';
import 'package:appartment_app_group_2/features/applications/data/firebase_application_repository.dart';
import 'package:appartment_app_group_2/features/applications/models/rental_application.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/application_fixtures.dart';

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> pumpApp(WidgetTester tester) async {
    final auth = signedInApplicant();
    await tester.pumpWidget(
      HomeFlowApp(
        authRepository: auth,
        apartmentRepository: const ApartmentRepository(delay: Duration.zero),
        applicationRepository: FirebaseApplicationRepository(
          firestore: firestore,
          authRepository: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openApplicationsTab(WidgetTester tester) async {
    await tester.tap(find.text('Applications'));
    await tester.pumpAndSettle();
  }

  Future<void> openFirstApplication(WidgetTester tester) async {
    await openApplicationsTab(tester);
    await tester.tap(find.text('Bright apartment near the old town'));
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('applies for an apartment and tracks it in My applications', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(
      find.widgetWithText(ApartmentCard, 'Bright apartment near the old town'),
    );
    await tester.pumpAndSettle();
    await tapButton(tester, 'Apply');

    await tester.enterText(_field('Full name'), 'Anna Muster');
    await tester.enterText(_field('Phone'), '+41 79 123 45 67');
    await tester.enterText(_field('Number of occupants'), '2');
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Submit application');

    // The new application opens with its status.
    expect(find.widgetWithText(AppBar, 'Application'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.text('Anna Muster'), findsOneWidget);

    // Tapping the active tab returns to its first page, the list.
    await openApplicationsTab(tester);
    expect(find.widgetWithText(AppBar, 'My applications'), findsOneWidget);
    expect(find.text('Bright apartment near the old town'), findsOneWidget);
    expect(find.textContaining('Editable until'), findsOneWidget);
  });

  testWidgets('shows validation errors instead of submitting', (tester) async {
    await pumpApp(tester);
    await tester.tap(
      find.widgetWithText(ApartmentCard, 'Bright apartment near the old town'),
    );
    await tester.pumpAndSettle();
    await tapButton(tester, 'Apply');
    await tapButton(tester, 'Submit application');

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Choose a move-in date.'), findsOneWidget);
    expect((await firestore.collection('applications').get()).docs, isEmpty);
  });

  testWidgets('shows an empty state without applications', (tester) async {
    await pumpApp(tester);
    await openApplicationsTab(tester);

    expect(
      find.text('You have not applied for an apartment yet.'),
      findsOneWidget,
    );
  });

  testWidgets('edits an application within 5 days', (tester) async {
    await seedApplication(firestore, id: 'a1');
    await pumpApp(tester);
    await openFirstApplication(tester);

    await tapButton(tester, 'Edit');
    expect(find.widgetWithText(AppBar, 'Edit application'), findsOneWidget);
    await tester.enterText(_field('Phone'), '+41 27 606 85 11');
    await tapButton(tester, 'Save changes');

    expect(find.widgetWithText(AppBar, 'Application'), findsOneWidget);
    expect(find.text('+41 27 606 85 11'), findsOneWidget);
  });

  testWidgets('withdraws an application after confirming', (tester) async {
    await seedApplication(firestore, id: 'a1');
    await pumpApp(tester);
    await openFirstApplication(tester);

    await tapButton(tester, 'Withdraw');
    expect(find.text('Withdraw application?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text(ApplicationStatus.withdrawn.label), findsOneWidget);
    expect(find.text('You withdrew this application.'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('cancelling the dialog keeps the application', (tester) async {
    await seedApplication(firestore, id: 'a1');
    await pumpApp(tester);
    await openFirstApplication(tester);

    await tapButton(tester, 'Withdraw');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final data = (await firestore.collection('applications').doc('a1').get())
        .data()!;
    expect(data['status'], 'submitted');
  });

  testWidgets('hides edit and withdraw after 5 days', (tester) async {
    await seedApplication(
      firestore,
      id: 'a1',
      submittedAgo: const Duration(days: 6),
    );
    await pumpApp(tester);
    await openFirstApplication(tester);

    expect(
      find.text('The 5 days to edit or withdraw this application have passed.'),
      findsOneWidget,
    );
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Withdraw'), findsNothing);
  });

  testWidgets('shows the status set by the advertiser', (tester) async {
    await seedApplication(
      firestore,
      id: 'a1',
      status: ApplicationStatus.underReview,
    );
    await pumpApp(tester);
    await openApplicationsTab(tester);

    expect(find.text('Under review'), findsOneWidget);
  });
}
