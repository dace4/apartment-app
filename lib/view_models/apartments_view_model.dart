import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/apartment_filter.dart';
import '../models/app_user.dart';
import '../services/apartment_service.dart';

/// Shared by the apartment list and the Filters page, so both see the same
/// filter (see ARCHITECTURE.md §4).
class ApartmentsViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ApartmentsViewModel({ApartmentService? service, this.user})
    : service = service ?? ApartmentService();

  final ApartmentService service;

  /// US-04: supplied by the session, or the favourites auth listener.
  AppUser? user;

  /// Consumer roles constrain browsing independently of optional filters.
  ListingType? get restrictedListingType {
    final account = user;
    if (account == null || account.isRenter == account.isBuyer) return null;
    return account.isRenter ? ListingType.rent : ListingType.sale;
  }

  String? get listingTypeNotice => switch (restrictedListingType) {
    ListingType.rent => 'Rentals only',
    ListingType.sale => 'Sales only',
    null => null,
  };

  String filterPriceUnit(ListingType? selectedType) =>
      (restrictedListingType ?? selectedType) == ListingType.rent
      ? 'CHF / month'
      : 'CHF';

  List<Apartment> apartments = [];
  bool isLoading = false;
  String? errorMessage;

  /// Chips above the list. null means "All".
  ApartmentAvailability? availability;

  /// Criteria chosen on the Filters page.
  ApartmentFilter filter = const ApartmentFilter();

  /// US 23: true right after filters are applied, to offer saving them.
  bool askToSaveSearch = false;

  /// The apartments matching both the availability and the filter.
  List<Apartment> get visibleApartments => apartments
      .where(
        (apartment) =>
            (restrictedListingType == null ||
                apartment.listingType == restrictedListingType) &&
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

  /// [askToSave] is false when the filter comes from a saved search.
  void applyFilter(ApartmentFilter value, {bool askToSave = true}) {
    filter = value;
    askToSaveSearch = askToSave && !value.isEmpty;
    notifyListeners();
  }

  void dismissSaveSearch() {
    askToSaveSearch = false;
    notifyListeners();
  }

  void clearFilters() {
    availability = null;
    filter = const ApartmentFilter();
    askToSaveSearch = false;
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
