import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../services/apartment_service.dart';

class ApartmentDetailViewModel extends ChangeNotifier {
  final ApartmentService service = ApartmentService();
  StreamSubscription<Apartment?>? _subscription;

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
