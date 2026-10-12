import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/application_service.dart';

/// US 16: the user's applications, updated live so a new, edited or
/// withdrawn application appears without reloading.
class ApplicationsViewModel extends ChangeNotifier {
  final ApplicationService service = ApplicationService();
  StreamSubscription<List<RentalApplication>>? _subscription;

  List<RentalApplication> applications = [];
  bool isLoading = false;
  String? errorMessage;

  void listenToApplications() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service.watchMyApplications().listen(
      (newApplications) {
        applications = newApplications;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = 'Could not load your applications.';
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
