import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';

/// US 16: the applications received for the apartments the user owns
/// (Homeowner) or manages (Property Manager).
class InboxViewModel extends ChangeNotifier {
  InboxViewModel(
    this._user, {
    ApartmentService? apartmentService,
    ApplicationService? applicationService,
  }) : apartmentService = apartmentService ?? ApartmentService(),
       applicationService = applicationService ?? ApplicationService();

  /// The signed-in user, read when the inbox loads.
  final AppUser? Function() _user;
  final ApartmentService apartmentService;
  final ApplicationService applicationService;
  bool _disposed = false;

  List<RentalApplication> applications = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> fetchInbox() async {
    final user = _user();
    if (user == null || !user.isReady || !user.hasManagementRole) {
      errorMessage = 'Choose Homeowner or Property Manager to see the inbox.';
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final apartments = await apartmentService.getManagedApartments(user);
      final ids = [for (final apartment in apartments) apartment.id];
      applications = await applicationService.getApplicationsForApartments(ids);
    } catch (e) {
      errorMessage = 'Could not load your inbox.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
