import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/application_service.dart';

/// US 16: the user's applications, updated live so a new, edited or
/// withdrawn application appears without reloading.
class ApplicationsViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ApplicationsViewModel({this._canAccess});
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
  final ApplicationService service = ApplicationService();
  StreamSubscription<List<RentalApplication>>? _subscription;

  List<RentalApplication> applications = [];
  bool isLoading = false;
  String? errorMessage;

  /// Whether the application can still be edited or withdrawn (5 days).
  bool canChange(RentalApplication application) =>
      application.canChange(DateTime.now());

  void listenToApplications() {
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
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
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
