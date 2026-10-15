import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';

/// US 16: the user's applications, updated live so a new, edited or
/// withdrawn application appears without reloading.
class ApplicationsViewModel extends ChangeNotifier {
  final ApplicationService service = ApplicationService();
  final ApartmentService apartmentService = ApartmentService();
  StreamSubscription<List<RentalApplication>>? _subscription;
  final Set<String> _checkingReservation = {};

  List<RentalApplication> applications = [];
  bool isLoading = false;
  String? errorMessage;

  /// Whether the application can still be edited or withdrawn (5 days).
  bool canChange(RentalApplication application) =>
      application.canChange(DateTime.now());

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
        unawaited(_withdrawApplicationsForReservedApartments(newApplications));
      },
      onError: (e) {
        errorMessage = 'Could not load your applications.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  /// A renter cannot keep an open application once another application's
  /// immediate reservation has won the apartment. This runs when the list is
  /// opened and is also safe to repeat on later live updates.
  Future<void> _withdrawApplicationsForReservedApartments(
    List<RentalApplication> currentApplications,
  ) async {
    // .toList() makes the filtering (and the _checkingReservation.add side
    // effect) run once, right now, instead of lazily.
    final candidates = currentApplications
        .where(
          (application) =>
              application.status.isOpen &&
              _checkingReservation.add(application.id),
        )
        .toList();

    await Future.wait(
      candidates.map((application) async {
        try {
          final reservedByAnother = await apartmentService
              .isReservedByAnotherApplication(
                application.apartmentId,
                application.id,
              );
          if (reservedByAnother) {
            await service.withdraw(application.id);
          }
        } catch (_) {
          // Keep the application visible if the check cannot be completed.
        } finally {
          _checkingReservation.remove(application.id);
        }
      }),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
