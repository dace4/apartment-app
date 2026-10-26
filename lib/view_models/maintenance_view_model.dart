import 'package:flutter/foundation.dart';

import '../models/app_maintenance.dart';
import '../services/app_maintenance_service.dart';
import '../utils/formatters.dart';

/// The admin's Repair & maintenance page: the form that schedules an app
/// maintenance window ("from" and "till"). The current window itself comes
/// from the shared AppMaintenanceViewModel.
class MaintenanceViewModel extends ChangeNotifier {
  // Tests pass a fake service and clock; the app uses Firebase and the time.
  MaintenanceViewModel({
    AppMaintenanceService? service,
    DateTime Function()? clock,
  }) : service = service ?? AppMaintenanceService(),
       _clock = clock ?? DateTime.now;

  final AppMaintenanceService service;
  final DateTime Function() _clock;

  /// Null means "now": the window starts as soon as it is saved.
  DateTime? start;
  DateTime? end;
  bool isSaving = false;
  String? actionError;

  String get startLabel => start == null ? 'Now' : formatDateTime(start!);
  String get endLabel => end == null ? 'Choose a time' : formatDateTime(end!);

  void setStart(DateTime value) {
    start = value;
    actionError = null;
    notifyListeners();
  }

  void setEnd(DateTime value) {
    end = value;
    actionError = null;
    notifyListeners();
  }

  /// The reason the window cannot be saved, or null when it is valid.
  String? validate() {
    final now = _clock();
    final from = start ?? now;
    if (end == null) return 'Choose when the maintenance ends.';
    if (!end!.isAfter(now)) return 'The end must be in the future.';
    if (!end!.isAfter(from)) return 'The end must be after the start.';
    return null;
  }

  Future<bool> schedule() async {
    final error = validate();
    if (error != null) {
      actionError = error;
      notifyListeners();
      return false;
    }
    isSaving = true;
    actionError = null;
    notifyListeners();
    try {
      await service.schedule(
        AppMaintenance(start: start ?? _clock(), end: end!),
      );
      start = null;
      end = null;
      return true;
    } catch (e) {
      actionError = 'Could not schedule the maintenance. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> endNow() async {
    isSaving = true;
    actionError = null;
    notifyListeners();
    try {
      await service.endNow();
      return true;
    } catch (e) {
      actionError = 'Could not end the maintenance. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
