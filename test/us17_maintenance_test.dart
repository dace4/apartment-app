import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/app_notification.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/maintenance_request.dart';
import 'package:appartment_app_group_2/models/notification_preferences.dart';
import 'package:appartment_app_group_2/models/user_role.dart';
import 'package:appartment_app_group_2/services/auth_service.dart';
import 'package:appartment_app_group_2/services/maintenance_service.dart';
import 'package:appartment_app_group_2/services/notification_service.dart';
import 'package:appartment_app_group_2/view_models/maintenance_booking_view_model.dart';
import 'package:appartment_app_group_2/view_models/maintenance_reminders_view_model.dart';

/// Monday 2 November 2026, 10:00.
final monday = DateTime(2026, 11, 2, 10);
final tuesday = DateTime(2026, 11, 3);
final saturday = DateTime(2026, 11, 7);

/// Sprint 3 review: only property managers book maintenance.
const owner = AppUser(
  id: 'owner',
  email: 'owner@test.ch',
  emailVerified: true,
  roles: {UserRole.propertyManager},
);

Apartment flat(String id, String title) => Apartment(
  id: id,
  title: title,
  address: 'Rue 1',
  city: 'Sion',
  listingType: ListingType.rent,
  price: 1500,
  rooms: 3,
  surface: 70,
  imageUrl: '',
  description: '',
  ownerId: 'owner',
);

MaintenanceRequest service({
  String id = 'r1',
  required DateTime slotStart,
  Set<MaintenanceReminder> reminders = const {
    MaintenanceReminder.oneDay,
    MaintenanceReminder.oneHour,
  },
  MaintenanceStatus status = MaintenanceStatus.scheduled,
}) => MaintenanceRequest(
  id: id,
  userId: 'owner',
  apartmentId: 'a1',
  apartmentTitle: 'Flat in Sion',
  category: MaintenanceCategory.plumbing,
  description: 'Leaking tap',
  slotStart: slotStart,
  reminders: reminders,
  status: status,
);

class FakeAuth extends Fake implements AuthService {
  final users = StreamController<AppUser?>.broadcast();
  AppUser? user = owner;

  @override
  Stream<AppUser?> userChanges() => users.stream;

  @override
  Future<AppUser?> loadUser() async => user;
}

class FakeMaintenance extends Fake implements MaintenanceService {
  List<Apartment> managed = [flat('a1', 'Flat in Sion')];
  List<MaintenanceRequest> requests = [];
  final live = StreamController<List<MaintenanceRequest>>.broadcast();
  final booked = <DateTime>[];
  final rescheduled = <DateTime>[];

  @override
  Future<List<Apartment>> getManageableApartments() async => [...managed];

  @override
  Future<List<MaintenanceRequest>> getMyRequests() async => requests;

  @override
  Stream<List<MaintenanceRequest>> watchMyRequests() => live.stream;

  @override
  Future<MaintenanceRequest?> getRequest(String id) async =>
      requests.where((request) => request.id == id).firstOrNull;

  @override
  Future<String> book({
    required Apartment apartment,
    required MaintenanceCategory category,
    required String description,
    required DateTime slotStart,
    required Set<MaintenanceReminder> reminders,
  }) async {
    booked.add(slotStart);
    return 'new';
  }

  @override
  Future<void> reschedule(
    String id,
    DateTime slotStart,
    Set<MaintenanceReminder> reminders,
  ) async => rescheduled.add(slotStart);
}

class FakeNotifications extends Fake implements NotificationService {
  final notifications = StreamController<List<AppNotification>>.broadcast();
  final preferences = StreamController<NotificationPreferences>.broadcast();
  final saved = <AppNotification>[];

  @override
  Stream<List<AppNotification>> watchMyNotifications() => notifications.stream;

  @override
  Stream<NotificationPreferences> watchPreferences() => preferences.stream;

  @override
  Future<void> addWithFixedId(AppNotification notification) async =>
      saved.add(notification);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('US-17.1 only owners and assigned managers can book', () {
    test('the form lists only the properties the user owns or manages',
        () async {
      final fake = FakeMaintenance()
        ..managed = [flat('b', 'Zurich loft'), flat('a', 'Aarau flat')];
      final viewModel = MaintenanceBookingViewModel(
        service: fake,
        authService: FakeAuth(),
        clock: () => monday,
      );

      await viewModel.load();

      expect(viewModel.apartments.map((a) => a.title), [
        'Aarau flat',
        'Zurich loft',
      ]);
    });

    test('booking is refused when the property is no longer managed',
        () async {
      final fake = FakeMaintenance();
      final viewModel = MaintenanceBookingViewModel(
        service: fake,
        authService: FakeAuth(),
        clock: () => monday,
      );
      await viewModel.load();
      viewModel
        ..selectApartment(fake.managed.first)
        ..selectCategory(MaintenanceCategory.heating)
        ..selectDate(tuesday);
      fake.managed = []; // the assignment was removed meanwhile

      expect(await viewModel.book('No heating'), isFalse);
      expect(viewModel.actionError, 'You do not manage this property.');
      expect(fake.booked, isEmpty);
    });
  });

  group('US-17.2 the time wheel only offers valid slots', () {
    test('choosing a date selects its first free time', () async {
      final fake = FakeMaintenance()
        ..requests = [service(slotStart: DateTime(2026, 11, 3, 8))];
      final viewModel = MaintenanceBookingViewModel(
        service: fake,
        authService: FakeAuth(),
        clock: () => monday,
      );
      await viewModel.load();

      viewModel.selectDate(tuesday);

      // 08:00 is already booked by the user, so the wheel starts at 08:30.
      expect(viewModel.availableSlots.first, DateTime(2026, 11, 3, 8, 30));
      expect(viewModel.slot, DateTime(2026, 11, 3, 8, 30));
      expect(viewModel.availableSlots, isNot(contains(DateTime(2026, 11, 3, 8))));
      // 12:00–13:00 is the lunch break; the last slot ends at 17:00.
      expect(viewModel.availableSlots, isNot(contains(DateTime(2026, 11, 3, 12))));
      expect(viewModel.availableSlots.last, DateTime(2026, 11, 3, 16, 30));
    });

    test('weekends and today have no slots; the same date keeps the time',
        () async {
      final viewModel = MaintenanceBookingViewModel(
        service: FakeMaintenance(),
        authService: FakeAuth(),
        clock: () => monday,
      );
      await viewModel.load();

      viewModel.selectDate(saturday);
      expect(viewModel.availableSlots, isEmpty);
      expect(viewModel.slot, isNull);

      viewModel.selectDate(monday); // today: from tomorrow only
      expect(viewModel.availableSlots, isEmpty);

      viewModel
        ..selectDate(tuesday)
        ..selectSlot(DateTime(2026, 11, 3, 14))
        ..selectDate(tuesday);
      expect(viewModel.slot, DateTime(2026, 11, 3, 14));
    });
  });

  group('US-17.4 booking, rescheduling and cancellation', () {
    test('a service is booked in the chosen slot', () async {
      final fake = FakeMaintenance();
      final viewModel = MaintenanceBookingViewModel(
        service: fake,
        authService: FakeAuth(),
        clock: () => monday,
      );
      await viewModel.load();
      viewModel
        ..selectApartment(fake.managed.first)
        ..selectCategory(MaintenanceCategory.plumbing)
        ..selectDate(tuesday)
        ..selectSlot(DateTime(2026, 11, 3, 9));

      expect(await viewModel.book('Leaking tap'), isTrue);
      expect(fake.booked, [DateTime(2026, 11, 3, 9)]);
      expect(viewModel.savedId, 'new');
    });

    test('rescheduling moves the service and keeps it out of its old slot',
        () async {
      final existing = service(slotStart: DateTime(2026, 11, 3, 9));
      final fake = FakeMaintenance()..requests = [existing];
      final viewModel = MaintenanceBookingViewModel(
        service: fake,
        authService: FakeAuth(),
        clock: () => monday,
      );
      await viewModel.load(rescheduleId: 'r1');
      viewModel.selectDate(tuesday);

      expect(viewModel.slotState(existing.slotStart), SlotState.current);
      expect(viewModel.availableSlots, isNot(contains(existing.slotStart)));

      viewModel.selectSlot(DateTime(2026, 11, 3, 15));
      expect(await viewModel.reschedule(), isTrue);
      expect(fake.rescheduled, [DateTime(2026, 11, 3, 15)]);
    });

    test('a service can change only before it starts and if not cancelled',
        () {
      final scheduled = service(slotStart: DateTime(2026, 11, 3, 9));
      expect(scheduled.canChange(monday), isTrue);
      expect(scheduled.canChange(DateTime(2026, 11, 3, 9)), isFalse);
      expect(scheduled.isDone(DateTime(2026, 11, 3, 9, 30)), isTrue);

      final cancelled = service(
        slotStart: DateTime(2026, 11, 3, 9),
        status: MaintenanceStatus.cancelled,
      );
      expect(cancelled.canChange(monday), isFalse);
      expect(cancelled.dueReminders(DateTime(2026, 11, 3, 8, 30)), isEmpty);
    });

    test('reminder timing: the closest due reminder until the service starts',
        () {
      final request = service(slotStart: DateTime(2026, 11, 3, 9));

      expect(request.latestDueReminder(DateTime(2026, 11, 2, 8, 59)), isNull);
      expect(
        request.latestDueReminder(DateTime(2026, 11, 2, 9)),
        MaintenanceReminder.oneDay,
      );
      expect(
        request.latestDueReminder(DateTime(2026, 11, 3, 8, 10)),
        MaintenanceReminder.oneHour,
      );
      // 5 minutes before was not chosen, so 1 hour stays the latest.
      expect(
        request.latestDueReminder(DateTime(2026, 11, 3, 8, 58)),
        MaintenanceReminder.oneHour,
      );
      expect(request.latestDueReminder(DateTime(2026, 11, 3, 9)), isNull);
    });
  });

  group('US-17.3 reminders become in-app notifications', () {
    late FakeAuth auth;
    late FakeMaintenance maintenance;
    late FakeNotifications notifications;
    late DateTime now;
    late MaintenanceRemindersViewModel viewModel;

    setUp(() async {
      auth = FakeAuth();
      maintenance = FakeMaintenance();
      notifications = FakeNotifications();
      now = DateTime(2026, 11, 3, 8, 10); // 50 minutes before the service
      viewModel = MaintenanceRemindersViewModel(
        authService: auth,
        service: maintenance,
        notificationService: notifications,
        clock: () => now,
      );
      auth.users.add(owner);
      await settle();
    });

    tearDown(() => viewModel.dispose());

    Future<void> load({
      List<AppNotification> stored = const [],
      NotificationPreferences preferences = const NotificationPreferences(),
    }) async {
      maintenance.live.add([service(slotStart: DateTime(2026, 11, 3, 9))]);
      notifications.notifications.add(stored);
      notifications.preferences.add(preferences);
      await settle();
    }

    test('a due reminder is saved once, with a fixed id', () async {
      await load();

      expect(notifications.saved, hasLength(1));
      final saved = notifications.saved.single;
      expect(saved.id, 'maintenance_r1_oneHour');
      expect(saved.type, NotificationType.maintenance);
      expect(saved.title, 'Plumbing service in 1 hour');
      expect(saved.maintenanceId, 'r1');
      expect(viewModel.dueReminders.single.reminder, MaintenanceReminder.oneHour);

      // New data or a later check does not send it again.
      maintenance.live.add([service(slotStart: DateTime(2026, 11, 3, 9))]);
      await settle();
      expect(notifications.saved, hasLength(1));
    });

    test('nothing is saved when the reminder already exists', () async {
      await load(
        stored: [
          AppNotification(
            id: 'owner_maintenance_r1_oneHour',
            type: NotificationType.maintenance,
            title: 'Plumbing service in 1 hour',
            body: '',
            createdAt: now,
          ),
        ],
      );
      expect(notifications.saved, isEmpty);
    });

    test('it is saved even when maintenance alerts are off', () async {
      await load(
        preferences: const NotificationPreferences(maintenance: false),
      );
      // Sprint 3 review: the inbox always gets it; only the badge is off.
      expect(notifications.saved, hasLength(1));
      expect(viewModel.dueReminders, hasLength(1));
    });

    test('homeowners are no longer reminded (property managers only)',
        () async {
      auth.users.add(
        const AppUser(
          id: 'home',
          email: 'home@test.ch',
          emailVerified: true,
          roles: {UserRole.homeowner},
        ),
      );
      await settle();
      expect(maintenance.live.hasListener, isFalse);
    });

    test('nothing is saved before the reminder time', () async {
      now = DateTime(2026, 11, 2, 8); // more than a day before
      await load();
      expect(notifications.saved, isEmpty);
      expect(viewModel.dueReminders, isEmpty);
    });
  });
}
