import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/application_service.dart';

/// US 16: one application, updated live, that can be withdrawn within
/// 5 days.
class ApplicationDetailViewModel extends ChangeNotifier {
  final ApplicationService service = ApplicationService();
  StreamSubscription<RentalApplication?>? _subscription;

  /// null once loaded means the application does not exist.
  RentalApplication? application;
  bool isLoading = false;
  String? errorMessage;

  bool isWithdrawing = false;
  String? actionError;

  bool get canChange => application?.canChange(DateTime.now()) ?? false;

  void listenToApplication(String id) {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = service
        .watchApplication(id)
        .listen(
          (newApplication) {
            application = newApplication;
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            errorMessage = 'Could not load the application.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  /// The new status arrives through the live update.
  Future<void> withdraw() async {
    if (!canChange) return;
    isWithdrawing = true;
    actionError = null;
    notifyListeners();

    try {
      await service.withdraw(application!.id);
    } catch (e) {
      actionError = 'Could not withdraw the application. Please try again.';
    } finally {
      isWithdrawing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
