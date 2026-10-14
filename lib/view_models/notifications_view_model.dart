import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/notification_preferences.dart';
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

  int get unreadCount => notifications.where((n) => !n.isRead).length;

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
