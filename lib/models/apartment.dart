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
  });

  final String id;
  final String title;

  final String address;
  final String city;

  final ListingType listingType;

  final int price;

  final double rooms;

  final int surface;

  final String imageUrl;
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
    description: description,
    amenities: amenities,
    availability: availability ?? this.availability,
  );

  factory Apartment.fromMap(String id, Map<String, dynamic> map) {
    return Apartment(
      id: id,
      title: map['title'] as String,
      address: map['address'] as String,
      city: map['city'] as String,
      // Enums are stored by name, e.g. "rent" or "available".
      listingType: ListingType.values.byName(map['listingType'] as String),
      price: map['price'] as int,
      // Firestore stores 3 as an int and 3.5 as a double: accept both.
      rooms: (map['rooms'] as num).toDouble(),
      surface: map['surface'] as int,
      imageUrl: map['imageUrl'] as String,
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
      'description': description,
      'availability': availability.name,
      // Firestore has no Set: store a list of names.
      'amenities': amenities.map((amenity) => amenity.name).toList(),
    };
  }
}
