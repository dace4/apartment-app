import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/application_service.dart';

/// US 16: edit an application within 5 days of submitting it.
class EditApplicationViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  EditApplicationViewModel({this._canAccess});
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
  final ApplicationService service = ApplicationService();

  /// Read once: the form keeps the user's edits even if the stored
  /// application changes meanwhile. null once loaded means it does not exist.
  RentalApplication? application;
  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? actionError;

  bool get canChange => application?.canChange(DateTime.now()) ?? false;

  Future<void> fetchApplication(String id) async {
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
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

  /// Returns true when the changes were saved.
  Future<bool> save(ApplicationDetails details) async {
    if (!hasAccess) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      await service.update(application!.id, details);
      return true;
    } catch (e) {
      actionError = 'Could not save the changes. Please try again.';
      return false;
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
