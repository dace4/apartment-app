import 'package:cloud_firestore/cloud_firestore.dart';

import 'apartment_filter.dart';
import 'apartment.dart';

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filter,
    required this.alertsEnabled,
    required this.seenApartmentIds,
    required this.createdAt,
  });

  static const maxPerUser = 5;

  final String id;
  final String name;
  final ApartmentFilter filter;

  final bool alertsEnabled;

  final Set<String> seenApartmentIds;
  final DateTime createdAt;

  static bool isOffer(ApartmentFilter filter, Apartment apartment) =>
      apartment.availability == ApartmentAvailability.available &&
      filter.matches(apartment);

  bool isNewOffer(Apartment apartment) =>
      isOffer(filter, apartment) && !seenApartmentIds.contains(apartment.id);

  List<Apartment> findNewOffers(List<Apartment> apartments) =>
      apartments.where(isNewOffer).toList();

  factory SavedSearch.fromMap(String id, Map<String, dynamic> map) {
    return SavedSearch(
      id: id,
      name: map['name'] as String,
      filter: ApartmentFilter.fromMap(map['filter'] as Map<String, dynamic>),
      alertsEnabled: map['alertsEnabled'] as bool,
      seenApartmentIds: (map['seenApartmentIds'] as List)
          .cast<String>()
          .toSet(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
