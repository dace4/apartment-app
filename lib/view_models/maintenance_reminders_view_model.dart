import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/maintenance_request.dart';
import '../services/auth_service.dart';
import '../services/maintenance_service.dart';
import '../services/notification_service.dart';

/// A reminder that is due now.
typedef DueReminder = ({
  MaintenanceRequest request,
  MaintenanceReminder reminder,
});

/// US-17 acceptance criterion: "System sends notification before scheduled
/// service". When a reminder is due, it is shown as a banner on every tab
/// and saved once as a US 18 notification (type maintenance), so it is also
/// in Profile → Notifications. It is always saved: the "Maintenance" switch
/// only controls the alert (Sprint 3 review). Shared by every tab (ARCHITECTURE.md §4), so
/// it is created once in app.dart and shown by the bottom navigation shell.
class MaintenanceRemindersViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass fakes and a fixed clock; the app uses Firebase and now().
  MaintenanceRemindersViewModel({
    AuthService? authService,
    MaintenanceService? service,
    NotificationService? notificationService,
    DateTime Function()? clock,
  }) : authService = authService ?? AuthService(),
       service = service ?? MaintenanceService(),
       notificationService = notificationService ?? NotificationService(),
       _now = clock ?? DateTime.now {
    _authSubscription = this.authService.userChanges().listen(_onUserChanged);
    // Re-checks every minute which reminders are due, and retries loading
    // after an error.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  final AuthService authService;
  final MaintenanceService service;
  final NotificationService notificationService;
  final DateTime Function() _now;

  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<List<MaintenanceRequest>>? _subscription;
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  late final Timer _timer;

  String? _userId;
  bool _loadFailed = false;
  List<MaintenanceRequest> _requests = [];

  /// Ids of the user's stored notifications; null until loaded, so nothing
  /// is sent before we know which reminders already exist.
  Set<String>? _notificationIds;

  /// Reminder notifications being saved, so a tick does not send them twice.
  final Set<String> _sending = {};

  /// Dismissed reminders, as "requestId:reminder", until the app restarts.
  final Set<String> _dismissed = {};

  /// For each upcoming service, the due reminder closest to it.
  List<DueReminder> get _latestDue {
    final now = _now();
    return [
      for (final request in _requests)
        if (request.latestDueReminder(now) case final reminder?)
          (request: request, reminder: reminder),
    ];
  }

  /// Due reminders that were not dismissed, soonest service first.
  List<DueReminder> get dueReminders => [
    for (final due in _latestDue)
      if (!_dismissed.contains(_key(due.request, due.reminder))) due,
  ];

  void dismiss(DueReminder due) {
    _dismissed.add(_key(due.request, due.reminder));
    notifyListeners();
  }

  String _key(MaintenanceRequest request, MaintenanceReminder reminder) =>
      '${request.id}:${reminder.name}';

  void _tick() {
    if (_loadFailed) _listen();
    _sendDueNotifications();
    notifyListeners();
  }

  /// Saves each due reminder once as a notification. The fixed document id
  /// and firestore.rules prevent duplicates even across several phones.
  Future<void> _sendDueNotifications() async {
    final userId = _userId;
    final stored = _notificationIds;
    if (userId == null || stored == null) return;

    for (final due in _latestDue) {
      final notification = AppNotification.maintenanceReminder(
        due.request,
        due.reminder,
        createdAt: _now(),
      );
      final documentId = '${userId}_${notification.id}';
      if (stored.contains(documentId) || _sending.contains(documentId)) {
        continue;
      }
      _sending.add(documentId);
      try {
        await notificationService.addWithFixedId(notification);
        // The live list will contain it; until then, do not send it again.
        _notificationIds?.add(documentId);
      } catch (e) {
        // Refused when it already exists; otherwise retried next minute.
      } finally {
        _sending.remove(documentId);
      }
    }
  }

  /// Reads Firestore only for a verified user (firestore.rules require it).
  void _onUserChanged(AppUser? user) {
    // Sprint 3 review: only property managers book maintenance.
    final userId = user?.isReady == true && user!.isPropertyManager
        ? user.id
        : null;
    // userChanges also fires on token refresh; nothing changed then.
    if (userId == _userId) return;
    _userId = userId;
    _dismissed.clear();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _notificationsSubscription?.cancel();
    _subscription = null;
    _notificationsSubscription = null;
    _requests = [];
    _notificationIds = null;
    _loadFailed = false;
    if (_userId != null) {
      _subscription = service.watchMyRequests().listen(
        (requests) {
          _requests = requests;
          _sendDueNotifications();
          notifyListeners();
        },
        onError: (e) {
          // For example right after verifying the email, before the new
          // login token arrives. The timer retries.
          _loadFailed = true;
          notifyListeners();
        },
      );
      _notificationsSubscription = notificationService
          .watchMyNotifications()
          .listen((notifications) {
            _notificationIds = {
              for (final notification in notifications) notification.id,
            };
            _sendDueNotifications();
          }, onError: (e) => _loadFailed = true);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _subscription?.cancel();
    _notificationsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
