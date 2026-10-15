import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';
import '../services/reservation_exceptions.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// US 16: one application, updated live, that can be withdrawn within
/// 5 days.
class ApplicationDetailViewModel extends ChangeNotifier {
  final ApplicationService service = ApplicationService();
  final ApartmentService apartmentService = ApartmentService();
  final NotificationService notificationService = NotificationService();

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
    if (!canChange) return;
    isWithdrawing = true;
    actionError = null;
    notifyListeners();

    try {
      await service.withdraw(application!.id);
      await _notify(ApplicationStatus.withdrawn);
    } catch (e) {
      actionError = 'Could not withdraw the application. Please try again.';
    } finally {
      isWithdrawing = false;
      notifyListeners();
    }
  }

  /// Returns true when the reservation was committed.
  Future<bool> applyImmediately() async {
    if (!canApplyImmediately || isReserving) return false;
    isReserving = true;
    actionError = null;
    notifyListeners();

    try {
      await service.reserveImmediately(application!);
      await _notify(ApplicationStatus.reserved);
      return true;
    } catch (error) {
      actionError = reservationErrorMessage(error);
      return false;
    } finally {
      isReserving = false;
      notifyListeners();
    }
  }

  // US 18: a failed notification must not undo a successful change.
  Future<void> _notify(ApplicationStatus status) async {
    try {
      await notificationService.add(
        AppNotification.applicationUpdate(
          apartmentTitle: application!.apartmentTitle,
          status: status,
        ),
      );
    } catch (e) {
      // Ignored: the application change itself was saved.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
