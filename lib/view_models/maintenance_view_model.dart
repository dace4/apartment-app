import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/maintenance_request.dart';
import '../services/maintenance_service.dart';

/// US-17: the user's maintenance requests, updated live, split into
/// upcoming and past or cancelled.
class MaintenanceViewModel extends ChangeNotifier {
  final MaintenanceService service = MaintenanceService();
  StreamSubscription<List<MaintenanceRequest>>? _subscription;

  /// Soonest first.
  List<MaintenanceRequest> requests = [];
  bool isLoading = false;
  String? errorMessage;

  bool _isUpcoming(MaintenanceRequest request) =>
      !request.isCancelled && !request.isDone(DateTime.now());

  /// Scheduled services that have not ended, soonest first.
  List<MaintenanceRequest> get upcoming => requests.where(_isUpcoming).toList();

  /// Done and cancelled services, most recent first.
  List<MaintenanceRequest> get past => requests
      .where((request) => !_isUpcoming(request))
      .toList()
      .reversed
      .toList();

  void listenToRequests() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service.watchMyRequests().listen(
      (newRequests) {
        requests = newRequests;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = 'Could not load your maintenance services.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
