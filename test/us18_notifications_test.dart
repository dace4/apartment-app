import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/app_notification.dart';
import 'package:appartment_app_group_2/models/notification_preferences.dart';
import 'package:appartment_app_group_2/services/notification_service.dart';
import 'package:appartment_app_group_2/view_models/notifications_view_model.dart';

/// Replaces Firebase: the test pushes data in and records what is saved.
class FakeNotificationService extends Fake implements NotificationService {
  final notifications = StreamController<List<AppNotification>>();
  final preferences = StreamController<NotificationPreferences>();
  NotificationPreferences? saved;
  final readIds = <String>[];

  @override
  Stream<List<AppNotification>> watchMyNotifications() => notifications.stream;

  @override
  Stream<NotificationPreferences> watchPreferences() => preferences.stream;

  @override
  Future<void> savePreferences(NotificationPreferences value) async {
    saved = value;
    preferences.add(value); // Firestore sends the saved value back.
  }

  @override
  Future<void> markAsRead(String notificationId) async =>
      readIds.add(notificationId);
}

AppNotification _notification(
  String id,
  NotificationType type, {
  required int day,
  bool isRead = false,
}) => AppNotification(
  id: id,
  type: type,
  title: 'Title $id',
  body: 'Body $id',
  createdAt: DateTime(2026, 10, day),
  isRead: isRead,
);

/// Lets the streams deliver their data to the ViewModel.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeNotificationService service;
  late NotificationsViewModel viewModel;

  setUp(() {
    service = FakeNotificationService();
    viewModel = NotificationsViewModel(service: service)..listen();
  });

  tearDown(() => viewModel.dispose());

  test('shows the newest notification first', () async {
    service.notifications.add([
      _notification('old', NotificationType.announcement, day: 1),
      _notification('new', NotificationType.announcement, day: 10),
    ]);
    await _flush();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.notifications.map((n) => n.id), ['new', 'old']);
  });

  test('hides the kinds the user opted out of', () async {
    service.notifications.add([
      _notification('listing', NotificationType.newListing, day: 1),
      _notification('news', NotificationType.announcement, day: 2),
    ]);
    service.preferences.add(const NotificationPreferences(announcement: false));
    await _flush();

    expect(viewModel.notifications.map((n) => n.id), ['listing']);
  });

  test('counts only visible unread notifications', () async {
    service.notifications.add([
      _notification('a', NotificationType.newListing, day: 1),
      _notification('b', NotificationType.newListing, day: 2, isRead: true),
      _notification('c', NotificationType.announcement, day: 3),
    ]);
    service.preferences.add(const NotificationPreferences(announcement: false));
    await _flush();

    expect(viewModel.unreadCount, 1);
  });

  // US-20: unreadCount drives the red dot on the Profile tab and tile.
  test('a new visit counts as unread until read or switched off', () async {
    service.notifications.add([
      _notification('visit', NotificationType.visit, day: 1),
    ]);
    await _flush();
    expect(viewModel.unreadCount, 1);

    service.notifications.add([
      _notification('visit', NotificationType.visit, day: 1, isRead: true),
    ]);
    await _flush();
    expect(viewModel.unreadCount, 0);

    service.notifications.add([
      _notification('visit', NotificationType.visit, day: 1),
    ]);
    service.preferences.add(const NotificationPreferences(visit: false));
    await _flush();
    expect(viewModel.unreadCount, 0);
  });

  test('saves an opt-out and an opt-in', () async {
    await viewModel.setEnabled(NotificationType.newListing, false);
    await _flush();

    expect(service.saved!.newListing, isFalse);
    expect(
      viewModel.preferences.isEnabled(NotificationType.newListing),
      isFalse,
    );
    // The other switches keep their value.
    expect(service.saved!.announcement, isTrue);

    await viewModel.setEnabled(NotificationType.newListing, true);
    await _flush();

    expect(service.saved!.newListing, isTrue);
  });

  test('mark all as read only touches unread notifications', () async {
    service.notifications.add([
      _notification('a', NotificationType.newListing, day: 1),
      _notification('b', NotificationType.newListing, day: 2, isRead: true),
    ]);
    await _flush();

    await viewModel.markAllAsRead();

    expect(service.readIds, ['a']);
  });

  test('shows an error message when loading fails', () async {
    service.notifications.addError(Exception('offline'));
    await _flush();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNotNull);
  });
}
