import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';

/// US 16: the application form for one apartment.
class ApplyViewModel extends ChangeNotifier {
  final ApartmentService apartmentService = ApartmentService();
  final ApplicationService applicationService = ApplicationService();

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? saveError;

  Future<void> fetchApartment(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await apartmentService.getApartment(id);
    } catch (e) {
      errorMessage = 'Could not load the apartment.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the application was submitted.
  Future<bool> submit(ApplicationDetails details) async {
    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      // Only one open application per apartment.
      final myApplications = await applicationService.getMyApplications();
      final alreadyApplied = myApplications.any(
        (application) =>
            application.apartmentId == apartment!.id &&
            application.status.isOpen,
      );
      if (alreadyApplied) {
        saveError = 'You already have an open application for this apartment.';
        return false;
      }

      await applicationService.submit(apartment!, details);
      return true;
    } catch (e) {
      saveError = 'Could not submit the application. Please try again.';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
