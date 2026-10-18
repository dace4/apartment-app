import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/maintenance_request.dart';
import '../services/maintenance_service.dart';

/// US-17: one maintenance request, updated live, that can be cancelled
/// until the service starts.
class MaintenanceDetailViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final MaintenanceService service = MaintenanceService();
  StreamSubscription<MaintenanceRequest?>? _subscription;

  /// null once loaded means the request does not exist.
  MaintenanceRequest? request;
  bool isLoading = false;
  String? errorMessage;

  bool isCancelling = false;
  String? actionError;

  bool get canChange => request?.canChange(DateTime.now()) ?? false;
  bool get isDone => request?.isDone(DateTime.now()) ?? false;

  void listenToRequest(String id) {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service
        .watchRequest(id)
        .listen(
          (newRequest) {
            request = newRequest;
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            errorMessage = 'Could not load the maintenance service.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  /// The new status arrives through the live update.
  Future<void> cancel() async {
    if (!canChange) return;
    isCancelling = true;
    actionError = null;
    notifyListeners();

    try {
      await service.cancel(request!.id);
    } catch (e) {
      actionError = 'Could not cancel the service. Please try again.';
    } finally {
      isCancelling = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
