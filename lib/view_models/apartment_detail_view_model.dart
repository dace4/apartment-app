import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../services/apartment_service.dart';

class ApartmentDetailViewModel extends ChangeNotifier {
  final ApartmentService service = ApartmentService();

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchApartment(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await service.getApartment(id);
    } catch (e) {
      errorMessage = 'Could not load this apartment.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
