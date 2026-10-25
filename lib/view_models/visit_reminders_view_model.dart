import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/visit.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/visit_service.dart';

/// US 18.4: upcoming-event notifications. The day before a booked visit,
/// the visitor receives a "Visit tomorrow" notification, saved once. Shared
/// by every tab (ARCHITECTURE.md §4), so it is created once in app.dart; it
/// has no page of its own, the notification appears in Profile →
/// Notifications.
class VisitRemindersViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass fakes and a fixed clock; the app uses Firebase and now().
  VisitRemindersViewModel({
    AuthService? authService,
    VisitService? visitService,
    NotificationService? notificationService,
    DateTime Function()? clock,
  }) : authService = authService ?? AuthService(),
       visitService = visitService ?? VisitService(),
       notificationService = notificationService ?? NotificationService(),
       _now = clock ?? DateTime.now {
    _authSubscription = this.authService.userChanges().listen(_onUserChanged);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  final AuthService authService;
  final VisitService visitService;
  final NotificationService notificationService;
  final DateTime Function() _now;

  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<List<Visit>>? _visitsSubscription;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  late final Timer _timer;

  String? _userId;
  bool _loadFailed = false;
  List<Visit> _visits = [];

  /// null until loaded, so nothing is sent before we know which reminders
  /// exist.
  Set<String>? _notificationIds;
  final Set<String> _sending = {};

  /// The visits whose reminder is due now.
  List<Visit> get dueVisits {
    final now = _now();
    return _visits.where((visit) => visit.isReminderDue(now)).toList();
  }

  void _tick() {
    if (_loadFailed) _listen();
    _sendDueReminders();
  }

  /// Saves each due reminder once; the "Visits" switch only controls the
  /// alert (Sprint 3 review). The fixed document id and firestore.rules
  /// prevent duplicates.
  Future<void> _sendDueReminders() async {
    final userId = _userId;
    final stored = _notificationIds;
    if (userId == null || stored == null) return;

    for (final visit in dueVisits) {
      final notification = AppNotification.visitReminder(
        visit,
        createdAt: _now(),
      );
      final documentId = '${userId}_${notification.id}';
      if (stored.contains(documentId) || _sending.contains(documentId)) {
        continue;
      }
      _sending.add(documentId);
      try {
        await notificationService.addWithFixedId(notification);
        _notificationIds?.add(documentId);
      } catch (e) {
        // Refused when it already exists; otherwise retried next minute.
      } finally {
        _sending.remove(documentId);
      }
    }
  }

  /// Only renters and buyers book visits (firestore.rules require it).
  void _onUserChanged(AppUser? user) {
    final userId = user?.isReady == true && user!.isConsumer ? user.id : null;
    if (userId == _userId) return;
    _userId = userId;
    _listen();
  }

  void _listen() {
    _visitsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _visitsSubscription = null;
    _notificationsSubscription = null;
    _visits = [];
    _notificationIds = null;
    _loadFailed = false;
    if (_userId != null) {
      _visitsSubscription = visitService.watchMyVisits().listen((visits) {
        _visits = visits;
        _sendDueReminders();
        notifyListeners();
      }, onError: (e) => _loadFailed = true);
      _notificationsSubscription = notificationService
          .watchMyNotifications()
          .listen((notifications) {
            _notificationIds = {
              for (final notification in notifications) notification.id,
            };
            _sendDueReminders();
          }, onError: (e) => _loadFailed = true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _visitsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
