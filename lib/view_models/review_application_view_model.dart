import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/application_service.dart';

/// US 16: an application received by the owner or manager, who moves it
/// through Applied → Received → In review → Accepted or Rejected.
class ReviewApplicationViewModel extends ChangeNotifier {
  ReviewApplicationViewModel({ApplicationService? service})
    : service = service ?? ApplicationService();

  final ApplicationService service;
  bool _disposed = false;

  /// null once loaded means the application does not exist.
  RentalApplication? application;
  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? actionError;

  /// The statuses that can be chosen next; empty once decided or withdrawn.
  List<ApplicationStatus> get nextSteps =>
      application?.status.reviewSteps ?? [];

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> fetchApplication(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      application = await service.getApplication(id);
    } catch (e) {
      errorMessage = 'Could not load the application.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the new status and notifies the applicant.
  Future<void> review(ApplicationStatus status) async {
    final current = application;
    if (current == null || isSaving || !nextSteps.contains(status)) return;
    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      await service.review(current, status);
      application = await service.getApplication(current.id);
    } catch (e) {
      // e.g. the applicant withdrew it meanwhile.
      actionError = 'Could not update the application. Reload and try again.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
