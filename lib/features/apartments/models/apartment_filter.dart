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
}
