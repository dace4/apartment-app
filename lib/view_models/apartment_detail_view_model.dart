import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/visit.dart';
import '../services/apartment_service.dart';
import '../services/visit_service.dart';

class ApartmentDetailViewModel extends ChangeNotifier {
  final ApartmentService service = ApartmentService();
  StreamSubscription<Apartment?>? _subscription;

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  /// US-20: the user's upcoming visit of this apartment, if any.
  Visit? myVisit;
  StreamSubscription<List<Visit>>? _visitSubscription;

  Future<void> fetchApartment(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = service
        .watchApartment(id)
        .listen(
          (updatedApartment) {
            apartment = updatedApartment;
            isLoading = false;
            notifyListeners();
          },
          onError: (_) {
            errorMessage = 'Could not load this apartment.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  /// US-20: only for renters and buyers, who can book visits.
  void listenToMyVisit(String apartmentId) {
    _visitSubscription?.cancel();
    _visitSubscription = VisitService().watchMyVisits().listen(
      (visits) {
        final now = DateTime.now();
        myVisit = visits
            .where((v) => v.apartmentId == apartmentId && v.isUpcoming(now))
            .firstOrNull;
        notifyListeners();
      },
      // The page still works without it: the booking page checks again.
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _visitSubscription?.cancel();
    super.dispose();
  }
}
