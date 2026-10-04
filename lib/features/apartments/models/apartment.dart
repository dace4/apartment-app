// Apartment is rent or sale
enum ListingType { rent, sale }

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

}