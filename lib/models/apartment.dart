// Apartment is rent or sale
enum ListingType { rent, sale }

/// US 8: the listing's availability status and its user-facing label.
enum ApartmentAvailability {
  available('Available'),
  reserved('Reserved'),
  unavailable('Unavailable');

  const ApartmentAvailability(this.label);
  final String label;
}

/// equipment an apartment can have, with its user-facing label.
enum Amenity {
  balcony('Balcony / terrace'),
  garden('Garden'),
  parking('Parking'),
  elevator('Elevator'),
  furnished('Furnished'),
  cellar('Cellar');

  const Amenity(this.label);
  final String label;
}

// One apartment listing, in the search result and detail page
class Apartment {
  const Apartment({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
    required this.listingType,
    required this.price,
    required this.rooms,
    required this.surface,
    required this.imageUrl,
    required this.description,
    this.availability = ApartmentAvailability.unavailable,
    this.amenities = const {},
    this.imageUrls = const [],
    this.ownerId,
    this.managerIds = const {},
    this.applicationId,
  });

  final String id;
  final String title;
  // US-24: set to the creator; existing assignments remain immutable.
  final String? ownerId;
  final Set<String> managerIds;

  /// The application that reserved it (In review) or won it (Accepted).
  /// Written only together with that application's review (firestore.rules).
  final String? applicationId;

  final String address;
  final String city;

  final ListingType listingType;

  final int price;

  final double rooms;

  final int surface;

  final String imageUrl;
  final List<String> imageUrls;

  /// US-24: old single-image listings remain readable.
  List<String> get galleryImages => imageUrls.isNotEmpty
      ? List.unmodifiable(imageUrls)
      : [if (imageUrl.isNotEmpty) imageUrl];
  final String description;
  // Unknown availability defaults to unavailable so old listings are safe.
  final ApartmentAvailability availability;

  /// equipment of the apartment, used by the amenities filter.
  final Set<Amenity> amenities;

  /// Controls the Apply button; opening the form does not reserve the apartment.
  bool get canApply => availability == ApartmentAvailability.available;

  /// US 13: price divided by surface, in CHF (per month for a rent).
  int get pricePerSquareMetre => surface == 0 ? 0 : (price / surface).round();

  /// Returns a new listing with changed availability and all other fields kept.
  Apartment copyWith({ApartmentAvailability? availability}) => Apartment(
    id: id,
    title: title,
    address: address,
    city: city,
    listingType: listingType,
    price: price,
    rooms: rooms,
    surface: surface,
    imageUrl: imageUrl,
    imageUrls: imageUrls,
    description: description,
    amenities: amenities,
    ownerId: ownerId,
    managerIds: managerIds,
    applicationId: applicationId,
    availability: availability ?? this.availability,
  );

  factory Apartment.fromMap(String id, Map<String, dynamic> map) {
    return Apartment(
      id: id,
      title: map['title'] as String,
      ownerId: map['ownerId'] is String ? map['ownerId'] as String : null,
      managerIds: map['managerIds'] is List
          ? Set.unmodifiable((map['managerIds'] as List).whereType<String>())
          : const {},
      applicationId: map['applicationId'] as String?,
      address: map['address'] as String,
      city: map['city'] as String,
      // Enums are stored by name, e.g. "rent" or "available".
      listingType: ListingType.values.byName(map['listingType'] as String),
      price: map['price'] as int,
      // Firestore stores 3 as an int and 3.5 as a double: accept both.
      rooms: (map['rooms'] as num).toDouble(),
      surface: map['surface'] as int,
      imageUrl: map['imageUrl'] as String? ?? '',
      imageUrls: map['imageUrls'] is List
          ? List.unmodifiable((map['imageUrls'] as List).whereType<String>())
          : const [],
      description: map['description'] as String,
      availability: ApartmentAvailability.values.byName(
        map['availability'] as String,
      ),
      amenities: (map['amenities'] as List)
          .map((name) => Amenity.values.byName(name as String))
          .toSet(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'address': address,
      'city': city,
      'listingType': listingType.name,
      'price': price,
      'rooms': rooms,
      'surface': surface,
      'imageUrl': imageUrl,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      'description': description,
      'availability': availability.name,
      // Firestore has no Set: store a list of names.
      'amenities': amenities.map((amenity) => amenity.name).toList(),
    };
  }
}
