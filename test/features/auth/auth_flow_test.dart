import 'package:appartment_app_group_2/app.dart';
import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';

Finder _field(String label) => find.widgetWithText(TextFormField, label);

final _welcome = find.text('Welcome to HomeFlow');
final _apartmentsPage = find.widgetWithText(AppBar, 'Apartments');

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(HomeFlowApp(authRepository: auth));
    await tester.pumpAndSettle();
  }

  group('access control', () {
    testWidgets('signed-out users start on the welcome page', (tester) async {
      await pumpApp(tester);

      expect(_welcome, findsOneWidget);
      expect(_apartmentsPage, findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('unverified users can only see the verify page', (
      tester,
    ) async {
      auth = FakeAuthRepository(
        currentUser: const AppUser(
          id: '1',
          email: 'anna@hevs.ch',
          emailVerified: false,
        ),
      );
      await pumpApp(tester);

      expect(find.widgetWithText(AppBar, 'Verify your email'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('US-06 create an account', () {
    testWidgets('registers, sends the confirmation email and asks to verify', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('No account yet? Create one'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Email'), 'anna@hevs.ch');
      await tester.enterText(_field('Password'), 'secret123');
      await tester.enterText(_field('Confirm password'), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.verificationEmailsSent, ['anna@hevs.ch']);
      expect(find.widgetWithText(AppBar, 'Verify your email'), findsOneWidget);

      // After clicking the link in the email, the user reaches the home page.
      auth.verifyEmail();
      await tester.tap(find.text('I have verified my email'));
      await tester.pumpAndSettle();
      expect(_apartmentsPage, findsOneWidget);
    });

    testWidgets('shows validation errors and does not register', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('No account yet? Create one'));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Email'), 'not-an-email');
      await tester.enterText(_field('Password'), 'short');
      await tester.enterText(_field('Confirm password'), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(auth.accounts, isEmpty);
    });
  });

  group('US-07 log in and log out', () {
    testWidgets('logs in and is directed to the home page', (tester) async {
      auth.accounts['anna@hevs.ch'] = 'secret123';
      await pumpApp(tester);

      await tester.enterText(_field('Email'), 'anna@hevs.ch');
      await tester.enterText(_field('Password'), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(auth.currentUser?.email, 'anna@hevs.ch');
      expect(_apartmentsPage, findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('shows an error for a wrong password', (tester) async {
      auth.accounts['anna@hevs.ch'] = 'secret123';
      await pumpApp(tester);

      await tester.enterText(_field('Email'), 'anna@hevs.ch');
      await tester.enterText(_field('Password'), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(auth.currentUser, isNull);
      expect(_welcome, findsOneWidget);
    });

    testWidgets('logs out from the profile page back to the welcome page', (
      tester,
    ) async {
      auth = FakeAuthRepository(
        currentUser: const AppUser(
          id: '1',
          email: 'anna@hevs.ch',
          emailVerified: true,
        ),
      );
      await pumpApp(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('anna@hevs.ch'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
      expect(_welcome, findsOneWidget);
    });
  });
}
