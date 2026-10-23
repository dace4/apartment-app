import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/insurance_coverage.dart';
import '../models/insurance_request.dart';
import '../services/insurance_service.dart';

/// US-19: the insurance coverage catalogue and the renter's requests.
class InsuranceViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass a service backed by a fake Firestore.
  InsuranceViewModel({InsuranceService? service})
    : service = service ?? InsuranceService();

  final InsuranceService service;
  StreamSubscription<List<InsuranceRequest>>? _subscription;

  List<InsuranceCoverage> coverages = [];
  bool isLoading = false;
  String? errorMessage;

  /// "My requests". A loading error only hides this section.
  List<InsuranceRequest> requests = [];
  String? requestsError;

  Future<void> fetchCoverages() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      coverages = await service.getCoverages();
    } catch (e) {
      errorMessage = 'Could not load the insurance coverages.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void listenToRequests() {
    requestsError = null;
    _subscription?.cancel();
    _subscription = service.watchMyRequests().listen(
      (updated) {
        requests = updated;
        requestsError = null;
        notifyListeners();
      },
      onError: (e) {
        requestsError = 'Could not load your requests.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
