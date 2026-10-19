import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/services/application_service.dart';
import 'package:appartment_app_group_2/services/message_service.dart';
import 'package:appartment_app_group_2/view_models/inbox_view_model.dart';
import 'package:appartment_app_group_2/view_models/message_detail_view_model.dart';

const manager = AppUser(
  id: 'manager',
  email: 'manager@example.test',
  emailVerified: true,
  roles: {UserRole.propertyManager},
);

Map<String, dynamic> apartmentData(List<String> managerIds) => {
  'title': 'Managed flat',
  'managerIds': managerIds,
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

Map<String, dynamic> messageData(String apartmentId, int day) => {
  'apartmentId': apartmentId,
  'advertiserId': 'advertiser',
  'senderId': 'tenant',
  'senderEmail': 'tenant@example.test',
  'subject': 'Question $day',
  'body': 'Is it still available?',
  'createdAt': Timestamp.fromDate(DateTime(2026, 10, day)),
  'status': 'sent',
};

void main() {
  late FakeFirebaseFirestore db;
  late MessageService messages;

  setUp(() async {
    db = FakeFirebaseFirestore();
    messages = MessageService(firestore: db);
    await db
        .collection('apartments')
        .doc('mine')
        .set(apartmentData(['manager']));
    await db.collection('apartments').doc('other').set(apartmentData([]));
    final collection = db.collection('advertiserMessages');
    await collection.doc('m1').set(messageData('mine', 1));
    await collection.doc('m2').set(messageData('mine', 3));
    await collection.doc('m3').set(messageData('other', 2));
  });

  test(
    'the inbox lists messages for managed apartments, newest first',
    () async {
      final inbox = InboxViewModel(
        () => manager,
        apartmentService: ApartmentService(firestore: db),
        applicationService: ApplicationService(
          firestore: db,
          currentUser: () => manager,
        ),
        messageService: messages,
      );

      await inbox.fetchInbox();

      expect(inbox.messages.map((m) => m.id), ['m2', 'm1']);
      expect(inbox.apartmentTitles['mine'], 'Managed flat');
    },
  );

  test('the detail shows the sender, subject and body', () async {
    final detail = MessageDetailViewModel(service: messages);

    await detail.fetchMessage('m1');

    expect(detail.message!.senderEmail, 'tenant@example.test');
    expect(detail.message!.subject, 'Question 1');
    expect(detail.message!.body, 'Is it still available?');

    await detail.fetchMessage('missing');
    expect(detail.message, isNull);
  });
}
