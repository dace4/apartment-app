import 'apartment.dart';

/// Every criterion is optional: an empty text, a null value or an empty set
/// means "no constraint". An apartment matches when it meets every criterion
/// that is set.
class ApartmentFilter {
  const ApartmentFilter({
    this.location = '',
    this.listingType,
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.minSurface,
    this.amenities = const {},
  });

  /// Part of the city or postcode, e.g. "Sion" or "1950".
  final String location;

  /// Rent or buy. Needed because rents are monthly and sale prices are totals.
  final ListingType? listingType;

  /// In CHF, compared with [Apartment.price].
  final int? minPrice;
  final int? maxPrice;

  final double? minRooms;

  /// In square metres.
  final int? minSurface;

  /// The apartment must have all of them.
  final Set<Amenity> amenities;

  /// True when no criterion is set, so every apartment matches.
  bool get isEmpty =>
      location.trim().isEmpty &&
      listingType == null &&
      minPrice == null &&
      maxPrice == null &&
      minRooms == null &&
      minSurface == null &&
      amenities.isEmpty;

  /// Whether [apartment] meets every criterion that is set.
  bool matches(Apartment apartment) {
    // Case-insensitive, so "sion" finds "1950 Sion".
    final query = location.trim().toLowerCase();
    if (query.isNotEmpty && !apartment.city.toLowerCase().contains(query)) {
      return false;
    }
    if (listingType != null && apartment.listingType != listingType) {
      return false;
    }
    if (minPrice != null && apartment.price < minPrice!) return false;
    if (maxPrice != null && apartment.price > maxPrice!) return false;
    if (minRooms != null && apartment.rooms < minRooms!) return false;
    if (minSurface != null && apartment.surface < minSurface!) return false;
    // An empty set is contained in any set, so no amenity means no constraint.
    return apartment.amenities.containsAll(amenities);
  }
}
