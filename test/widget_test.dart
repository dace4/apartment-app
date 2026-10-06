import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/app.dart';
import 'package:appartment_app_group_2/features/apartments/widgets/apartment_card.dart';

import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';

import 'fakes/fake_auth_repository.dart';

/// The app is only reachable after logging in with a verified email.
FakeAuthRepository _signedIn() => FakeAuthRepository(
  currentUser: const AppUser(
    id: '1',
    email: 'anna@hevs.ch',
    emailVerified: true,
  ),
);

void main() {
  testWidgets('starts on Apartments and switches tabs', (tester) async {
    await tester.pumpWidget(HomeFlowApp(authRepository: _signedIn()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Apartments'), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Services'), findsOneWidget);

    await tester.tap(find.text('Mortgage calculator'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Mortgage calculator'), findsOneWidget);
  });

  testWidgets('opens an apartment and its apply page', (tester) async {
    await tester.pumpWidget(HomeFlowApp(authRepository: _signedIn()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ApartmentCard, 'Bright apartment near the old town'),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Apartment details'), findsOneWidget);
    expect(find.text('Bright apartment near the old town'), findsOneWidget);

    // The Apply button is below the description, so scroll to it first.
    await tester.ensureVisible(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Apply for apartment 1'),
      findsOneWidget,
    );

    // Back button returns to the apartment detail.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Apartment details'), findsOneWidget);
  });
}
