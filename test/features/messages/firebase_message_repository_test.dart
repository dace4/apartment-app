import 'package:appartment_app_group_2/app.dart';
import 'package:appartment_app_group_2/features/apartments/data/apartment_repository.dart';
import 'package:appartment_app_group_2/features/apartments/widgets/apartment_card.dart';
import 'package:appartment_app_group_2/features/auth/data/auth_repository.dart';
import 'package:appartment_app_group_2/features/messages/data/firebase_contact_listing_repository.dart';
import 'package:appartment_app_group_2/features/messages/data/firebase_message_repository.dart';
import 'package:appartment_app_group_2/features/messages/data/message_repository.dart';
import 'package:appartment_app_group_2/features/messages/models/advertiser_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late FirebaseMessageRepository messages;
  late FirebaseContactListingRepository contacts;
  const apartments = ApartmentRepository(delay: Duration.zero);
  const listing = ContactListing(
    id: '1',
    title: 'Apartment',
    advertiserId: 'advertiser',
    advertiserName: 'Test advertiser',
  );
  MessageDraft draft({
    String id = 'enquiry',
    String body = 'Is it available?',
  }) => MessageDraft(id: id, listing: listing, subject: 'Enquiry', body: body);
  final fails = throwsA(isA<MessageException>());

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository(
      currentUser: const AppUser(
        id: 'sender',
        email: 'sender@example.com',
        emailVerified: true,
      ),
    );
    messages = FirebaseMessageRepository(
      firestore: firestore,
      authRepository: auth,
    );
    contacts = FirebaseContactListingRepository(
      firestore,
      apartmentRepository: apartments,
    );
    await firestore.collection('advertiserContacts').doc('1').set({
      'advertiserId': 'advertiser',
      'advertiserName': 'Test advertiser',
    });
  });

  test(
    'contact joins the sample title and streams recipient changes',
    () async {
      final stream = contacts.watchListing('1').asBroadcastStream();
      final initial = await stream.first;
      expect(initial!.title, (await apartments.fetchApartment('1'))!.title);
      expect(initial.advertiserId, 'advertiser');
      final changed = stream.firstWhere(
        (item) => item?.advertiserId == 'new-owner',
      );
      await firestore.collection('advertiserContacts').doc('1').update({
        'advertiserId': 'new-owner',
        'advertiserName': 'New advertiser',
      });
      expect((await changed)!.advertiserName, 'New advertiser');
      expect((await firestore.collection('apartments').get()).docs, isEmpty);
    },
  );

  test(
    'absent or malformed contacts disable sending for an existing sample',
    () async {
      expect((await contacts.watchListing('2').first)!.canContact, isFalse);
      await firestore.collection('advertiserContacts').doc('1').set({
        'advertiserId': 123,
        'advertiserName': null,
      });
      expect((await contacts.watchListing('1').first)!.canContact, isFalse);
      expect(await contacts.watchListing('missing').first, isNull);
    },
  );

  test(
    'successful submission stores authenticated identity and server timestamp',
    () async {
      final receipt = await messages.send(draft(body: '  Hello advertiser  '));
      expect(receipt.id, 'enquiry');
      final data =
          (await firestore
                  .collection('advertiserMessages')
                  .doc(receipt.id)
                  .get())
              .data()!;
      expect(data['senderId'], 'sender');
      expect(data['senderEmail'], 'sender@example.com');
      expect(data['advertiserId'], 'advertiser');
      expect(data['apartmentId'], '1');
      expect(data['body'], 'Hello advertiser');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['status'], 'sent');
    },
  );

  test(
    'confirmation retry preserves one message even after contact removal',
    () async {
      await messages.send(draft());
      await firestore.collection('advertiserContacts').doc('1').delete();
      expect((await messages.send(draft())).id, 'enquiry');
      expect(
        (await firestore.collection('advertiserMessages').get()).docs,
        hasLength(1),
      );
      await expectLater(messages.send(draft(body: 'Changed enquiry')), fails);
    },
  );

  test('deleted or reassigned contacts cannot receive a new enquiry', () async {
    await firestore.collection('advertiserContacts').doc('1').update({
      'advertiserId': 'new-owner',
    });
    await expectLater(messages.send(draft()), fails);
    await firestore.collection('advertiserContacts').doc('1').delete();
    await expectLater(messages.send(draft()), fails);
    expect(
      (await firestore.collection('advertiserMessages').get()).docs,
      isEmpty,
    );
  });

  test('signed-out and unverified users cannot submit directly', () async {
    auth.currentUser = null;
    await expectLater(messages.send(draft()), fails);
    auth.currentUser = const AppUser(
      id: 'sender',
      email: 'sender@example.com',
      emailVerified: false,
    );
    await expectLater(messages.send(draft()), fails);
    expect(
      (await firestore.collection('advertiserMessages').get()).docs,
      isEmpty,
    );
  });

  test('service rejects blank or overlong text without a write', () async {
    await expectLater(messages.send(draft(body: '   ')), fails);
    await expectLater(messages.send(draft(body: 'x' * 2001)), fails);
    await expectLater(
      messages.send(
        MessageDraft(
          id: 'invalid',
          listing: listing,
          subject: 'x' * 121,
          body: 'Hello',
        ),
      ),
      fails,
    );
    expect(
      (await firestore.collection('advertiserMessages').get()).docs,
      isEmpty,
    );
  });

  test('account changes during token refresh prevent submission', () async {
    messages = FirebaseMessageRepository(
      firestore: firestore,
      authRepository: auth,
      refreshSession: () async => auth.signOut(),
    );
    await expectLater(messages.send(draft()), fails);
    expect(
      (await firestore.collection('advertiserMessages').get()).docs,
      isEmpty,
    );
  });

  for (final code in [
    'permission-denied',
    'unavailable',
    'deadline-exceeded',
  ]) {
    test('$code yields the appropriate confirmation state', () async {
      messages = FirebaseMessageRepository(
        firestore: firestore,
        authRepository: auth,
        refreshSession: () async =>
            throw FirebaseException(plugin: 'cloud_firestore', code: code),
      );
      await expectLater(
        messages.send(draft()),
        throwsA(
          isA<MessageException>().having(
            (error) => error.confirmationPending,
            'pending',
            code != 'permission-denied',
          ),
        ),
      );
    });
  }

  testWidgets(
    'sample apartment contact submits through Firebase adapters and shows receipt',
    (tester) async {
      await tester.pumpWidget(
        HomeFlowApp(
          authRepository: auth,
          contactListingRepository: contacts,
          messageRepository: messages,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ApartmentCard).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Contact advertiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contact advertiser'));
      await tester.pumpAndSettle();
      expect(find.text('To: Test advertiser'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Message'),
        'US 12 test enquiry',
      );
      await tester.ensureVisible(find.text('Send message'));
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Message sent'), findsOneWidget);
      final saved =
          (await firestore.collection('advertiserMessages').get()).docs;
      expect(saved, hasLength(1));
      expect(saved.single.data()['body'], 'US 12 test enquiry');
      expect((await firestore.collection('apartments').get()).docs, isEmpty);
    },
  );
}
