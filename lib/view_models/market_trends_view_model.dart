import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../services/apartment_service.dart';

/// Current asking-price statistics from the same listings as the Home screen.
/// Listing creation dates are not historical price observations.
class MarketTrendsViewModel extends ChangeNotifier {
  MarketTrendsViewModel({ApartmentService? service})
    : _service = service ?? ApartmentService();

  final ApartmentService _service;
  StreamSubscription<List<Apartment>>? _subscription;
  List<Apartment> _apartments = const [];
  String? selectedCity;
  bool isLoading = false;
  String? errorMessage;
  bool _disposed = false;

  List<String> get cities =>
      _apartments.map((a) => a.city).toSet().toList()..sort();
  List<Apartment> get apartments => _apartments
      .where((a) => selectedCity == null || a.city == selectedCity)
      .toList();
  int get listingCount => apartments.length;
  int? get averagePrice => apartments.isEmpty
      ? null
      : (apartments.fold<double>(0, (total, a) => total + a.price) /
                listingCount)
            .round();
  int? get averagePricePerSquareMetre => apartments.isEmpty
      ? null
      : (apartments.fold<double>(0, (total, a) => total + a.price / a.surface) /
                listingCount)
            .round();
  int? get minimumPrice => apartments.isEmpty
      ? null
      : apartments.map((a) => a.price).reduce((a, b) => a < b ? a : b);
  int? get maximumPrice => apartments.isEmpty
      ? null
      : apartments.map((a) => a.price).reduce((a, b) => a > b ? a : b);

  void listenToApartments() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    _subscription?.cancel();
    _subscription = _service.watchApartments().listen(
      (entries) {
        if (_disposed) return;
        _apartments = List.unmodifiable(
          entries
              .where(
                (a) =>
                    a.listingType == ListingType.sale &&
                    a.availability != ApartmentAvailability.unavailable &&
                    a.price > 0 &&
                    a.surface > 0 &&
                    a.city.trim().isNotEmpty,
              )
              .toList()
            ..sort((a, b) {
              final city = a.city.compareTo(b.city);
              return city == 0 ? a.title.compareTo(b.title) : city;
            }),
        );
        if (!cities.contains(selectedCity)) selectedCity = null;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed) return;
        isLoading = false;
        errorMessage = 'Could not load apartment statistics. Check your connection and try again.';
        notifyListeners();
      },
    );
  }

  void selectCity(String? city) {
    selectedCity = city;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
