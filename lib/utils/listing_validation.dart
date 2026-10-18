import '../models/apartment.dart';

/// US-24: shared publication contract, used before the server write too.
String? validateListing(Apartment listing) {
  for (final field in [
    ('Title', listing.title, 200),
    ('Address', listing.address, 200),
    ('City', listing.city, 100),
    ('Description', listing.description, 5000),
  ]) {
    if (field.$2.trim().isEmpty || field.$2.length > field.$3) {
      return '${field.$1} is required (maximum ${field.$3} characters).';
    }
  }
  if (listing.price < 1 || listing.price > 1000000000) {
    return 'Enter a price from 1 to 1,000,000,000 CHF.';
  }
  if (!listing.rooms.isFinite || listing.rooms <= 0 || listing.rooms > 100) {
    return 'Enter a number of rooms greater than 0 and at most 100.';
  }
  if (listing.surface < 1 || listing.surface > 100000) {
    return 'Enter a surface from 1 to 100,000 m².';
  }
  final photos = listing.imageUrls;
  if (photos.length < 3 ||
      photos.length > 6 ||
      photos.toSet().length != photos.length) {
    return 'Choose 3 to 6 different pictures.';
  }
  if (photos.any(
    (photo) =>
        !photo.startsWith('data:image/jpeg;base64,/9j/') ||
        photo.length > 131095,
  )) {
    return 'Choose valid pictures no larger than 96 KiB after compression.';
  }
  return null;
}
