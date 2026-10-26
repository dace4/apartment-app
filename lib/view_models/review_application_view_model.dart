import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/rental_application.dart';
import '../services/apartment_service.dart';
import '../services/application_service.dart';

/// US 16: an application received by the owner or manager, who moves it
/// through Applied → Received → In review → Accepted or Rejected.
/// The apartment follows: In review reserves it, Accepted makes it
/// unavailable, and a rejected or withdrawn review frees it again.
class ReviewApplicationViewModel extends ChangeNotifier {
  ReviewApplicationViewModel({
    ApplicationService? service,
    ApartmentService? apartmentService,
  }) : service = service ?? ApplicationService(),
       apartmentService = apartmentService ?? ApartmentService();

  final ApplicationService service;
  final ApartmentService apartmentService;
  bool _disposed = false;

  /// null once loaded means the application does not exist.
  RentalApplication? application;

  /// The applied-for apartment, for its availability.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  bool isSaving = false;
  String? actionError;

  /// Another application holds the apartment: only one can be In review.
  bool get _heldByAnother =>
      apartment?.applicationId != null &&
      apartment!.applicationId != application?.id;

  /// The apartment is gone (another application was accepted, or it was
  /// made unavailable): this one can only be rejected.
  bool get _taken =>
      apartment?.availability == ApartmentAvailability.unavailable &&
      apartment!.applicationId != application?.id;

  /// The statuses that can be chosen next; empty once decided or withdrawn.
  List<ApplicationStatus> get nextSteps {
    final status = application?.status;
    if (status == null) return [];
    if (_taken && status.isOpen) return [ApplicationStatus.rejected];
    return status.reviewSteps
        .where(
          (step) =>
              step != ApplicationStatus.underReview ||
              apartment?.availability == ApartmentAvailability.available,
        )
        .toList();
  }

  /// Why "Start review" is missing, shown under the actions.
  String? get stepNotice {
    if (application?.status.isOpen != true) return null;
    if (_taken) return 'This apartment is no longer available.';
    if (application!.status != ApplicationStatus.received) return null;
    if (_heldByAnother) {
      return 'Another application is in review for this apartment. '
          'Accept or reject it first.';
    }
    if (apartment == null) return 'This apartment no longer exists.';
    if (apartment!.availability != ApartmentAvailability.available) {
      return 'This apartment is ${apartment!.availability.label.toLowerCase()}, '
          'so the review cannot start.';
    }
    return null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> fetchApplication(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _load(id);
    } catch (e) {
      errorMessage = 'Could not load the application.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _load(String id) async {
    application = await service.getApplication(id);
    apartment = application == null
        ? null
        : await apartmentService.getApartment(application!.apartmentId);
  }

  /// The apartment's new availability for [status], or null to leave it.
  ApartmentAvailability? _availabilityFor(ApplicationStatus status) =>
      switch (status) {
        ApplicationStatus.underReview => ApartmentAvailability.reserved,
        ApplicationStatus.accepted => ApartmentAvailability.unavailable,
        ApplicationStatus.rejected
            when apartment?.applicationId == application?.id =>
          ApartmentAvailability.available,
        _ => null,
      };

  /// Saves the new status, notifies the applicant and updates the
  /// apartment. Accepting also rejects the other open applications.
  Future<void> review(ApplicationStatus status) async {
    final current = application;
    if (current == null || isSaving || !nextSteps.contains(status)) return;
    isSaving = true;
    actionError = null;
    notifyListeners();

    try {
      await service.review(
        current,
        status,
        availability: _availabilityFor(status),
      );
      if (status == ApplicationStatus.accepted) {
        await _rejectOthers(current);
      }
      await _load(current.id);
    } catch (e) {
      // e.g. the applicant withdrew it meanwhile.
      actionError ??= 'Could not update the application. Reload and try again.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// One batch each, so one failure does not undo the acceptance. A failed
  /// one can still be rejected from its own page.
  Future<void> _rejectOthers(RentalApplication accepted) async {
    final others = (await service.getApplicationsForApartments([
      accepted.apartmentId,
    ])).where((other) => other.id != accepted.id && other.status.isOpen);
    var failed = 0;
    for (final other in others) {
      try {
        await service.review(other, ApplicationStatus.rejected);
      } catch (e) {
        failed++;
      }
    }
    if (failed > 0) {
      actionError =
          'Accepted. $failed other application(s) could not be rejected: '
          'open them from the inbox to reject them.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
