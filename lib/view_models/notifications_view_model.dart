import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/notification_preferences.dart';
import '../router/app_routes.dart';
import '../services/notification_service.dart';

/// US 18: the notification center and the opt-in / opt-out switches.
class NotificationsViewModel extends ChangeNotifier {
  // Tests pass a fake service; the app uses the real Firebase one.
  NotificationsViewModel({NotificationService? service})
    : service = service ?? NotificationService();

  final NotificationService service;

  List<AppNotification> _all = [];
  NotificationPreferences preferences = const NotificationPreferences();
  bool isLoading = false;
  String? errorMessage;
  String? actionError;

  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  StreamSubscription<NotificationPreferences>? _preferencesSubscription;

  /// Newest first, without the kinds the user switched off.
  List<AppNotification> get notifications =>
      _all.where((n) => preferences.isEnabled(n.type)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// US 18.3: shared by the Profile tab, the Notifications tile and this
  /// page, and updated live.
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// US 18.4: the page a notification opens, or null when it only informs.
  String? destinationFor(AppNotification notification) {
    final n = notification;
    return switch (n.type) {
      NotificationType.message when n.messageId != null => AppRoutes
          .inboxMessage(n.messageId!),
      NotificationType.newApplication when n.applicationId != null =>
        AppRoutes.inboxApplication(n.applicationId!),
      NotificationType.applicationStatus when n.applicationId != null =>
        AppRoutes.applicationDetail(n.applicationId!),
      NotificationType.maintenance when n.maintenanceId != null =>
        AppRoutes.maintenanceDetail(n.maintenanceId!),
      // US-20: the owner's visit; the visitor's reminder opens the apartment.
      _ when n.visitId != null => AppRoutes.inboxVisit(n.visitId!),
      _ when n.apartmentId != null => AppRoutes.apartmentDetail(
        n.apartmentId!,
      ),
      _ => null,
    };
  }

  /// Marks the notification as read and returns the page it opens.
  String? open(AppNotification notification) {
    markAsRead(notification);
    return destinationFor(notification);
  }

  /// Starts listening to the notifications and the switches (live data).
  void listen() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _notificationsSubscription?.cancel();
    _notificationsSubscription = service.watchMyNotifications().listen(
      (items) {
        _all = items;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = 'Could not load your notifications.';
        isLoading = false;
        notifyListeners();
      },
    );

    _preferencesSubscription?.cancel();
    _preferencesSubscription = service.watchPreferences().listen(
      (value) {
        preferences = value;
        notifyListeners();
      },
      onError: (e) {
        actionError = 'Could not load your notification settings.';
        notifyListeners();
      },
    );
  }

  /// Opt in or out of one kind. The switch follows the saved value, so it
  /// still shows the user's choice after logging out and in again.
  Future<void> setEnabled(NotificationType type, bool enabled) async {
    actionError = null;
    notifyListeners();
    try {
      await service.savePreferences(preferences.copyWithType(type, enabled));
    } catch (e) {
      actionError = 'Could not save your choice. Please try again.';
      notifyListeners();
    }
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await service.markAsRead(notification.id);
    } catch (e) {
      actionError = 'Could not update the notification.';
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      for (final notification in notifications.where((n) => !n.isRead)) {
        await service.markAsRead(notification.id);
      }
    } catch (e) {
      actionError = 'Could not update the notifications.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _preferencesSubscription?.cancel();
    super.dispose();
  }
}
