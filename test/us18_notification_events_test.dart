import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/app_notification.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/notification_preferences.dart';
import 'package:appartment_app_group_2/models/rental_application.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/models/visit.dart';
import 'package:appartment_app_group_2/router/app_routes.dart';
import 'package:appartment_app_group_2/services/application_service.dart';
import 'package:appartment_app_group_2/services/auth_service.dart';
import 'package:appartment_app_group_2/services/notification_service.dart';
import 'package:appartment_app_group_2/services/visit_service.dart';
import 'package:appartment_app_group_2/view_models/notifications_view_model.dart';
import 'package:appartment_app_group_2/view_models/visit_reminders_view_model.dart';

const renter = AppUser(
  id: 'renter',
  email: 'renter@test.ch',
  emailVerified: true,
  roles: {UserRole.renter},
);

Apartment flat({String? ownerId}) => Apartment(
  id: 'apt',
  title: 'Sunny apartment',
  address: 'Rue 1',
  city: 'Sion',
  listingType: ListingType.rent,
  price: 1500,
  rooms: 3,
  surface: 70,
  imageUrl: '',
  description: '',
  availability: ApartmentAvailability.available,
  ownerId: ownerId,
);

ApplicationDetails details() => ApplicationDetails(
  fullName: 'Renter Example',
  phone: '+41 79 123 45 67',
  moveInDate: DateTime.now().add(const Duration(days: 30)),
  occupants: 1,
);

AppNotification notification(
  String id,
  NotificationType type, {
  bool isRead = false,
  String? applicationId,
  String? messageId,
  String? apartmentId,
  String? visitId,
}) => AppNotification(
  id: id,
  type: type,
  title: id,
  body: '',
  createdAt: DateTime(2026, 10, 1),
  isRead: isRead,
  applicationId: applicationId,
  messageId: messageId,
  apartmentId: apartmentId,
  visitId: visitId,
);

Visit visit({required DateTime slotStart, String id = 'v1'}) => Visit(
  id: id,
  apartmentId: 'apt',
  apartmentTitle: 'Sunny apartment',
  ownerId: 'owner',
  visitorId: 'renter',
  visitorEmail: 'renter@test.ch',
  slotId: 'apt_20261103_0900',
  slotStart: slotStart,
  status: VisitStatus.booked,
);

class FakeNotifications extends Fake implements NotificationService {
  final notifications = StreamController<List<AppNotification>>.broadcast();
  final preferences = StreamController<NotificationPreferences>.broadcast();
  final saved = <AppNotification>[];
  final read = <String>[];

  @override
  Stream<List<AppNotification>> watchMyNotifications() => notifications.stream;

  @override
  Stream<NotificationPreferences> watchPreferences() => preferences.stream;

  @override
  Future<void> addWithFixedId(AppNotification notification) async =>
      saved.add(notification);

  @override
  Future<void> markAsRead(String notificationId) async =>
      read.add(notificationId);
}

class FakeAuth extends Fake implements AuthService {
  final users = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> userChanges() => users.stream;
}

class FakeVisits extends Fake implements VisitService {
  final visits = StreamController<List<Visit>>.broadcast();

  @override
  Stream<List<Visit>> watchMyVisits() => visits.stream;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('US 18.1 new kinds of notification and their switches', () {
    test('message and new application can be switched off and back on', () {
      const all = NotificationPreferences();
      final off = all
          .copyWithType(NotificationType.message, false)
          .copyWithType(NotificationType.newApplication, false);

      expect(off.isEnabled(NotificationType.message), isFalse);
      expect(off.isEnabled(NotificationType.newApplication), isFalse);
      expect(off.isEnabled(NotificationType.visit), isTrue);

      // Saved and read back the same.
      final reloaded = NotificationPreferences.fromMap(off.toMap());
      expect(reloaded.isEnabled(NotificationType.message), isFalse);
      expect(
        reloaded
            .copyWithType(NotificationType.message, true)
            .isEnabled(NotificationType.message),
        isTrue,
      );
    });

    test('preferences saved before these switches existed mean "on"', () {
      final old = NotificationPreferences.fromMap({
        'newListing': true,
        'applicationStatus': false,
        'announcement': true,
      });
      for (final type in NotificationType.values) {
        expect(
          old.isEnabled(type),
          type != NotificationType.applicationStatus,
          reason: type.name,
        );
      }
    });
  });

  group('US 18.2 owners are notified of new applications', () {
    test('submitting notifies the apartment owner, not the applicant',
        () async {
      final db = FakeFirebaseFirestore();
      final service = ApplicationService(
        firestore: db,
        currentUser: () => renter,
      );

      await service.submit(flat(ownerId: 'owner'), details());

      final notifications = (await db.collection('notifications').get()).docs;
      expect(notifications, hasLength(1));
      final data = notifications.single.data();
      final applications = (await db.collection('applications').get()).docs;
      expect(data['userId'], 'owner');
      expect(data['type'], 'newApplication');
      expect(data['applicationId'], applications.single.id);
      expect(data['isRead'], isFalse);
      expect(data['title'], 'New application: Sunny apartment');
    });

    test('an apartment without an owner notifies nobody', () async {
      final db = FakeFirebaseFirestore();
      await ApplicationService(
        firestore: db,
        currentUser: () => renter,
      ).submit(flat(), details());

      expect((await db.collection('notifications').get()).docs, isEmpty);
    });

    test('retrying the same submission does not notify twice', () async {
      final db = FakeFirebaseFirestore();
      final service = ApplicationService(
        firestore: db,
        currentUser: () => renter,
      );
      final id = service.newSubmissionId();

      await service.submit(flat(ownerId: 'owner'), details(), submissionId: id);
      await service.submit(flat(ownerId: 'owner'), details(), submissionId: id);

      expect((await db.collection('notifications').get()).docs, hasLength(1));
    });
  });

  group('US 18.3 shared unread count, updated live', () {
    test('the count follows new, read and switched-off notifications',
        () async {
      final fake = FakeNotifications();
      final viewModel = NotificationsViewModel(service: fake)..listen();

      fake.notifications.add([
        notification('m', NotificationType.message),
        notification('a', NotificationType.newApplication),
      ]);
      fake.preferences.add(const NotificationPreferences());
      await settle();
      expect(viewModel.unreadCount, 2);

      // Live: a new notification arrives.
      fake.notifications.add([
        notification('m', NotificationType.message),
        notification('a', NotificationType.newApplication),
        notification('v', NotificationType.visit),
      ]);
      await settle();
      expect(viewModel.unreadCount, 3);

      // Opt-out (Sprint 3 review): messages stay in the inbox but no
      // longer count in the red badge.
      fake.preferences.add(const NotificationPreferences(message: false));
      await settle();
      expect(viewModel.alertCount, 2);
      expect(viewModel.unreadCount, 3);
      expect(viewModel.notifications.map((n) => n.id), contains('m'));

      viewModel.dispose();
    });
  });

  group('US 18.4 destinations and read handling', () {
    final viewModel = NotificationsViewModel(service: FakeNotifications());

    test('each kind opens its page', () {
      expect(
        viewModel.destinationFor(
          notification('1', NotificationType.message, messageId: 'msg'),
        ),
        AppRoutes.inboxMessage('msg'),
      );
      expect(
        viewModel.destinationFor(
          notification('2', NotificationType.newApplication,
              applicationId: 'app'),
        ),
        AppRoutes.inboxApplication('app'),
      );
      expect(
        viewModel.destinationFor(
          notification('3', NotificationType.applicationStatus,
              applicationId: 'app'),
        ),
        AppRoutes.applicationDetail('app'),
      );
      expect(
        viewModel.destinationFor(
          notification('5', NotificationType.visit, visitId: 'v1'),
        ),
        AppRoutes.inboxVisit('v1'),
      );
      expect(
        viewModel.destinationFor(
          notification('6', NotificationType.visit, apartmentId: 'apt'),
        ),
        AppRoutes.apartmentDetail('apt'),
      );
      expect(
        viewModel.destinationFor(
          notification('7', NotificationType.announcement),
        ),
        isNull,
      );
    });

    test('opening a notification marks it as read', () async {
      final fake = FakeNotifications();
      final opened = NotificationsViewModel(service: fake);

      final destination = opened.open(
        notification('n1', NotificationType.message, messageId: 'msg'),
      );
      await settle();

      expect(destination, AppRoutes.inboxMessage('msg'));
      expect(fake.read, ['n1']);
    });

    test('a visit is reminded once, the day before, unless switched off',
        () async {
      final auth = FakeAuth();
      final visits = FakeVisits();
      final notifications = FakeNotifications();
      var now = DateTime(2026, 11, 2, 8); // more than a day before
      final reminders = VisitRemindersViewModel(
        authService: auth,
        visitService: visits,
        notificationService: notifications,
        clock: () => now,
      );
      auth.users.add(renter);
      await settle();

      final booked = visit(slotStart: DateTime(2026, 11, 3, 9));
      visits.visits.add([booked]);
      notifications.notifications.add([]);
      notifications.preferences.add(const NotificationPreferences());
      await settle();
      expect(notifications.saved, isEmpty);

      now = DateTime(2026, 11, 2, 9); // exactly one day before
      visits.visits.add([booked]);
      await settle();
      expect(notifications.saved, hasLength(1));
      final saved = notifications.saved.single;
      expect(saved.id, 'visitReminder_v1');
      expect(saved.type, NotificationType.visit);
      expect(saved.apartmentId, 'apt');
      expect(saved.title, 'Visit tomorrow: Sunny apartment');

      // Duplicate prevention: new data does not send it again.
      visits.visits.add([booked]);
      await settle();
      expect(notifications.saved, hasLength(1));

      reminders.dispose();
    });

    test('a visit reminder is stored even when its alerts are off', () async {
      final auth = FakeAuth();
      final visits = FakeVisits();
      final notifications = FakeNotifications();
      final reminders = VisitRemindersViewModel(
        authService: auth,
        visitService: visits,
        notificationService: notifications,
        clock: () => DateTime(2026, 11, 2, 12),
      );
      auth.users.add(renter);
      await settle();

      visits.visits.add([visit(slotStart: DateTime(2026, 11, 3, 9))]);
      notifications.notifications.add([]);
      notifications.preferences.add(
        const NotificationPreferences(visit: false),
      );
      await settle();
      // Sprint 3 review: the inbox always gets it; only the badge is off.
      expect(notifications.saved, hasLength(1));

      reminders.dispose();
    });
  });

  group('US 18.5 account isolation', () {
    test('owners and managers do not get visitor reminders', () async {
      final auth = FakeAuth();
      final visits = FakeVisits();
      final notifications = FakeNotifications();
      final reminders = VisitRemindersViewModel(
        authService: auth,
        visitService: visits,
        notificationService: notifications,
        clock: () => DateTime(2026, 11, 2, 12),
      );
      auth.users.add(
        const AppUser(
          id: 'owner',
          email: 'owner@test.ch',
          emailVerified: true,
          roles: {UserRole.homeowner},
        ),
      );
      await settle();

      // Not a renter or buyer: the visits are not even read.
      expect(visits.visits.hasListener, isFalse);
      expect(notifications.saved, isEmpty);

      reminders.dispose();
    });
  });
}
