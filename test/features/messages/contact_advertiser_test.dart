import 'dart:async';

import 'package:appartment_app_group_2/app.dart';
import 'package:appartment_app_group_2/features/apartments/widgets/apartment_card.dart';
import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';
import 'package:appartment_app_group_2/features/messages/data/contact_listing_repository.dart';
import 'package:appartment_app_group_2/features/messages/data/message_repository.dart';
import 'package:appartment_app_group_2/features/messages/models/advertiser_message.dart';
import 'package:appartment_app_group_2/features/messages/pages/contact_advertiser_page.dart';
import 'package:appartment_app_group_2/router/app_router.dart';
import 'package:appartment_app_group_2/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_message_repository.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

class MissingContact extends ContactListingRepository {
  const MissingContact({this.missingProperty = false, this.fail = false});
  final bool missingProperty;
  final bool fail;
  @override
  Stream<ContactListing?> watchListing(String id) async* {
    if (fail) throw StateError('Load failed');
    yield missingProperty
        ? null
        : ContactListing(
            id: id,
            title: 'Apartment',
            advertiserId: '',
            advertiserName: '',
          );
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeMessageRepository messages;
  setUp(() {
    auth = FakeAuthRepository(
      currentUser: const AppUser(
        id: 'sender',
        email: 'sender@example.com',
        emailVerified: true,
      ),
    );
    messages = FakeMessageRepository();
  });

  Future<void> page(
    WidgetTester tester, {
    ContactListingRepository listings = const SampleContactListingRepository(),
    Duration timeout = const Duration(seconds: 15),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ContactAdvertiserPage(
          apartmentId: '1',
          authRepository: auth,
          messageRepository: messages,
          listingRepository: listings,
          submissionTimeout: timeout,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      field('Message'),
      'Could I arrange a viewing next Friday?',
    );
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
  }

  testWidgets('opens from property detail and returns after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      HomeFlowApp(authRepository: auth, messageRepository: messages),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ApartmentCard).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Contact advertiser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact advertiser'));
    await tester.pumpAndSettle();
    expect(find.text('From: sender@example.com'), findsOneWidget);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Message sent'), findsOneWidget);
    expect(find.text('Reference: message-1'), findsOneWidget);
    expect(messages.submissions.single.listing.id, '1');
    await tester.tap(find.text('Back to apartment'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Apartment details'), findsOneWidget);
  });

  testWidgets(
    'default sample contact form never invents delivery confirmation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContactAdvertiserPage(apartmentId: '1', authRepository: auth),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('To: Sample advertiser'), findsOneWidget);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The message service is unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Message sent'), findsNothing);
      expect(
        find.text('Could I arrange a viewing next Friday?'),
        findsOneWidget,
      );
    },
  );

  testWidgets('validates whitespace and required fields before submitting', (
    tester,
  ) async {
    await page(tester);
    await tester.enterText(field('Subject'), ' ');
    await tester.enterText(field('Message'), '\n\t ');
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a subject.'), findsOneWidget);
    expect(find.text('Enter your message.'), findsOneWidget);
    expect(messages.submissions, isEmpty);
  });

  testWidgets(
    'shows success only after acknowledgement and prevents double submit',
    (tester) async {
      messages.pending = Completer<MessageReceipt>();
      await page(tester);
      await submit(tester);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Message sent'), findsNothing);
      expect(find.text('Sending…'), findsOneWidget);
      expect(messages.submissions, hasLength(1));
      messages.pending!.complete(const MessageReceipt('message-1'));
      await tester.pumpAndSettle();
      expect(find.text('Message sent'), findsOneWidget);
    },
  );

  testWidgets('service errors preserve input and allow a corrected retry', (
    tester,
  ) async {
    messages.error = const MessageException('Permission denied. Log in again.');
    await page(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Permission denied. Log in again.'), findsOneWidget);
    expect(find.text('Message sent'), findsNothing);
    expect(
      tester.widget<TextFormField>(field('Message')).controller!.text,
      'Could I arrange a viewing next Friday?',
    );
    messages.error = null;
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Message sent'), findsOneWidget);
  });

  testWidgets('an uncertain send freezes its draft and reuses the reference', (
    tester,
  ) async {
    messages.error = const MessageException(
      'Connection lost.',
      confirmationPending: true,
    );
    await page(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Check confirmation'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: field('Message'),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    messages.error = null;
    await tester.tap(find.text('Check confirmation'));
    await tester.pumpAndSettle();
    expect(messages.submissions[0].id, messages.submissions[1].id);
    expect(messages.createdIds, 1);
    expect(find.text('Message sent'), findsOneWidget);
  });

  testWidgets('a denied confirmation retry retains the uncertain reference', (
    tester,
  ) async {
    messages.error = const MessageException(
      'Connection lost.',
      confirmationPending: true,
    );
    await page(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    messages.error = const MessageException('Permission denied.');
    await tester.tap(find.text('Check confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('Check confirmation'), findsOneWidget);
    expect(find.text('Send message'), findsNothing);
    messages.error = null;
    await tester.tap(find.text('Check confirmation'));
    await tester.pumpAndSettle();
    expect(messages.createdIds, 1);
    expect(messages.submissions.map((draft) => draft.id).toSet(), {
      'message-1',
    });
    expect(find.text('Message sent'), findsOneWidget);
  });

  testWidgets('timeout never reports a send as successful', (tester) async {
    messages.pending = Completer<MessageReceipt>();
    await page(tester, timeout: const Duration(milliseconds: 100));
    await submit(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Message sent'), findsNothing);
    expect(find.text('Check confirmation'), findsOneWidget);
    messages.pending!.complete(const MessageReceipt('message-1'));
    await tester.pump();
    expect(find.text('Message sent'), findsNothing);
    messages.pending = null;
    await tester.tap(find.text('Check confirmation'));
    await tester.pumpAndSettle();
    expect(messages.submissions[0].id, messages.submissions[1].id);
    expect(find.text('Message sent'), findsOneWidget);
  });

  testWidgets('leaving while submitting causes no disposed-state errors', (
    tester,
  ) async {
    messages.pending = Completer<MessageReceipt>();
    await page(tester);
    await submit(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    messages.pending!.complete(const MessageReceipt('message-1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing advertiser and removed property cannot submit', (
    tester,
  ) async {
    await page(tester, listings: const MissingContact());
    expect(
      find.text('No advertiser contact is available for this apartment.'),
      findsOneWidget,
    );
    expect(find.text('Send message'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await page(tester, listings: const MissingContact(missingProperty: true));
    expect(find.text('This apartment is no longer listed.'), findsOneWidget);
    expect(messages.submissions, isEmpty);
  });

  testWidgets('listing load errors offer a retry', (tester) async {
    await page(tester, listings: const MissingContact(fail: true));
    expect(find.text('Could not load the advertiser.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the advertiser.'), findsOneWidget);
  });

  testWidgets('form supports a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await page(tester, textScale: 2);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Message sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final verified in [null, false]) {
    testWidgets(
      'contact deep link retains the authentication gate ($verified)',
      (tester) async {
        auth.currentUser = verified == null
            ? null
            : const AppUser(
                id: 'unverified',
                email: 'unverified@example.com',
                emailVerified: false,
              );
        final router = createAppRouter(
          authRepository: auth,
          messageRepository: messages,
        );
        addTearDown(router.dispose);
        router.go(AppRoutes.contactAdvertiser('1'));
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('Send message'), findsNothing);
        expect(
          find.text(
            verified == null ? 'Welcome to HomeFlow' : 'Verify your email',
          ),
          findsOneWidget,
        );
        expect(messages.submissions, isEmpty);
      },
    );
  }

  testWidgets('signing out hides the contact form immediately', (tester) async {
    await page(tester);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(
      find.text('Log in with a verified email to contact advertisers.'),
      findsOneWidget,
    );
    expect(find.text('Send message'), findsNothing);
  });
}
