import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/maintenance_request.dart';
import '../services/auth_service.dart';
import '../services/maintenance_service.dart';

/// A reminder that is due now.
typedef DueReminder = ({
  MaintenanceRequest request,
  MaintenanceReminder reminder,
});

/// US-17 acceptance criterion: the in-app reminder before a scheduled
/// service. Shared by every tab (ARCHITECTURE.md §4), so it is created once
/// in app.dart and shown by the bottom navigation shell.
class MaintenanceRemindersViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  MaintenanceRemindersViewModel() {
    _authSubscription = authService.userChanges().listen(_onUserChanged);
    // Re-checks every minute which reminders are due, and retries loading
    // after an error.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_loadFailed) _listen();
      notifyListeners();
    });
  }

  final AuthService authService = AuthService();
  final MaintenanceService service = MaintenanceService();
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<List<MaintenanceRequest>>? _subscription;
  late final Timer _timer;

  String? _userId;
  bool _loadFailed = false;
  List<MaintenanceRequest> _requests = [];

  /// Dismissed reminders, as "requestId:reminder", until the app restarts.
  final Set<String> _dismissed = {};

  /// Due reminders that were not dismissed, soonest service first.
  List<DueReminder> get dueReminders {
    final now = DateTime.now();
    return [
      for (final request in _requests)
        // When several are due, only the latest one (closest to the
        // service) is shown.
        for (final reminder in request.dueReminders(now).reversed.take(1))
          if (!_dismissed.contains(_key(request, reminder)))
            (request: request, reminder: reminder),
    ];
  }

  void dismiss(DueReminder due) {
    _dismissed.add(_key(due.request, due.reminder));
    notifyListeners();
  }

  String _key(MaintenanceRequest request, MaintenanceReminder reminder) =>
      '${request.id}:${reminder.name}';

  /// Reads Firestore only for a verified user (firestore.rules require it).
  void _onUserChanged(AppUser? user) {
    final userId = user?.isReady == true && user!.hasManagementRole
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
    _subscription = null;
    _requests = [];
    _loadFailed = false;
    if (_userId != null) {
      _subscription = service.watchMyRequests().listen(
        (requests) {
          _requests = requests;
          notifyListeners();
        },
        onError: (e) {
          // For example right after verifying the email, before the new
          // login token arrives. The timer retries.
          _loadFailed = true;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
