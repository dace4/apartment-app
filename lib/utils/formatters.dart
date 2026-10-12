import '../models/apartment.dart';

//Format an amoubt in Swiss francs with ' exemple => 1850 ; 1'850
String formatChf(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write("'");
    buffer.write(digits[i]);
  }
  return 'CHF $buffer';
}

// Format a date the Swiss way, e.g. 03.11.2026
String formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
}

//Format a swiss room count without a useless ".0"
String formatRooms(double rooms) {
  final number = rooms % 1 == 0 ? rooms.toInt().toString() : rooms.toString();
  return '$number rooms';
}

/// Price as shown to the user, e.g. "CHF 1'850 / month" or "CHF 890'000".
String formatApartmentPrice(Apartment apartment) =>
    switch (apartment.listingType) {
      ListingType.rent => '${formatChf(apartment.price)} / month',
      ListingType.sale => formatChf(apartment.price),
    };
