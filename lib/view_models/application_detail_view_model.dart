import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';
import '../services/reservation_exceptions.dart';

/// US 16: one application, updated live, that can be withdrawn within
/// 5 days.
class ApplicationDetailViewModel extends ChangeNotifier {
  ApplicationDetailViewModel({this._canAccess, this._canApplyImmediately});
  final bool Function()? _canApplyImmediately;
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
  final ApplicationService service = ApplicationService();
  final ApartmentService apartmentService = ApartmentService();
  StreamSubscription<RentalApplication?>? _subscription;
  bool _disposed = false;

  /// null once loaded means the application does not exist.
  RentalApplication? application;
  bool isLoading = false;
  String? errorMessage;

  bool isWithdrawing = false;
  bool isReserving = false;
  String? actionError;
  Apartment? apartment;
  bool isLoadingApartment = false;

  bool get canChange => application?.canChange(DateTime.now()) ?? false;

  bool get canApplyImmediately =>
      hasAccess &&
      _canApplyImmediately?.call() == true &&
      canChange &&
      application?.type == ApplicationType.normal &&
      apartment?.canApply == true;

  @override
  void notifyListeners() {
    // A request can finish after the screen has closed. Notifying a
    // disposed ChangeNotifier throws, so skip it in that case.
    if (!_disposed) super.notifyListeners();
  }

  void listenToApplication(String id) {
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
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
            if (newApplication != null) {
              _fetchApartment(newApplication.apartmentId);
            }
          },
          onError: (e) {
            errorMessage = 'Could not load the application.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> _fetchApartment(String apartmentId) async {
    isLoadingApartment = true;
    notifyListeners();
    try {
      apartment = await apartmentService.getApartment(apartmentId);
    } catch (_) {
      apartment = null;
    } finally {
      isLoadingApartment = false;
      notifyListeners();
    }
  }

  /// The new status arrives through the live update.
  Future<void> withdraw() async {
    if (!hasAccess) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
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

  /// Returns true when the reservation was committed.
  Future<bool> applyImmediately() async {
    if (!hasAccess || _canApplyImmediately?.call() != true) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return false;
    }
    if (!canApplyImmediately || isReserving) return false;
    isReserving = true;
    actionError = null;
    notifyListeners();

    try {
      await service.reserveImmediately(application!);
      return true;
    } catch (error) {
      actionError = reservationErrorMessage(error);
      return false;
    } finally {
      isReserving = false;
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
