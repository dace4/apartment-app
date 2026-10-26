import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_maintenance.dart';
import '../services/app_maintenance_service.dart';
import '../utils/formatters.dart';

/// The app maintenance window, shared by the whole app (see ARCHITECTURE.md
/// §4): the banner on every page, the router (non-admins are sent to the
/// maintenance page) and the admin's Repair & maintenance page.
class AppMaintenanceViewModel extends ChangeNotifier {
  // Tests pass a fake service and clock; the app uses Firebase and the time.
  AppMaintenanceViewModel({
    AppMaintenanceService? service,
    DateTime Function()? clock,
  }) : service = service ?? AppMaintenanceService(),
       _clock = clock ?? DateTime.now;

  final AppMaintenanceService service;
  final DateTime Function() _clock;

  AppMaintenance? maintenance;
  StreamSubscription<AppMaintenance?>? _subscription;
  Timer? _timer;

  bool get isActive => maintenance?.isActive(_clock()) ?? false;
  bool get isUpcoming => maintenance?.isUpcoming(_clock()) ?? false;

  /// The banner text, or null when no window is planned or running.
  String? get bannerMessage {
    final window = maintenance;
    if (window == null) return null;
    if (isActive) {
      return 'Maintenance in progress until ${formatDateTime(window.end)}.';
    }
    if (isUpcoming) {
      return 'Maintenance scheduled from ${formatDateTime(window.start)} '
          'till ${formatDateTime(window.end)}. The app will be unavailable.';
    }
    return null;
  }

  void listen() {
    _subscription?.cancel();
    _subscription = service.watch().listen(
      (window) {
        maintenance = window;
        _scheduleNextChange();
        notifyListeners();
      },
      // A read error must never lock users out: keep the last known window.
      onError: (Object e) {},
    );
  }

  /// The window starts and ends without the document changing, so wake up
  /// at the next boundary to update the banner and the router.
  void _scheduleNextChange() {
    _timer?.cancel();
    final window = maintenance;
    if (window == null) return;
    final now = _clock();
    final next = window.isUpcoming(now) ? window.start : window.end;
    if (!next.isAfter(now)) return;
    _timer = Timer(next.difference(now), () {
      _scheduleNextChange();
      notifyListeners();
    });
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
