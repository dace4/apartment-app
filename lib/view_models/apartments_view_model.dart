import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/apartment_filter.dart';
import '../services/apartment_service.dart';

/// Shared by the apartment list and the Filters page, so both see the same
/// filter (see ARCHITECTURE.md §4).
class ApartmentsViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final ApartmentService service = ApartmentService();

  List<Apartment> apartments = [];
  bool isLoading = false;
  String? errorMessage;

  /// Chips above the list. null means "All".
  ApartmentAvailability? availability;

  /// Criteria chosen on the Filters page.
  ApartmentFilter filter = const ApartmentFilter();

  /// The apartments matching both the availability and the filter.
  List<Apartment> get visibleApartments => apartments
      .where(
        (apartment) =>
            (availability == null || apartment.availability == availability) &&
            filter.matches(apartment),
      )
      .toList();

  bool get hasFilters => availability != null || !filter.isEmpty;

  Future<void> fetchApartments() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartments = await service.getApartments();
    } catch (e) {
      errorMessage = 'Could not load the apartments.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectAvailability(ApartmentAvailability? value) {
    availability = value;
    notifyListeners();
  }

  void applyFilter(ApartmentFilter value) {
    filter = value;
    notifyListeners();
  }

  void clearFilters() {
    availability = null;
    filter = const ApartmentFilter();
    notifyListeners();
  }

  /// Validator of the max price field: it cannot be under the min price.
  String? validateMaxPrice(String minPrice, String? maxPrice) {
    final min = int.tryParse(minPrice);
    final max = int.tryParse(maxPrice ?? '');
    if (min != null && max != null && max < min) {
      return 'Must be at least the minimum.';
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
