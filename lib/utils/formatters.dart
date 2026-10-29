import '../models/apartment_filter.dart';

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

/// US-09: a positive amount with centimes, e.g. 3194.5 => CHF 3'194.50
String formatChfCents(double amount) {
  final cents = (amount * 100).round();
  final centimes = (cents % 100).toString().padLeft(2, '0');
  return '${formatChf(cents ~/ 100)}.$centimes';
}

// Format a date the Swiss way, e.g. 03.11.2026
String formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
}

/// A date and time, e.g. "15.10.2026 22:30".
String formatDateTime(DateTime value) =>
    '${formatDate(value)} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

/// A time slot, e.g. "15.10.2026, 10:00–12:00".
String formatTimeSlot(DateTime start, DateTime end) =>
    '${formatDate(start)}, ${formatTimeRange(start, end)}';

/// US-20: the times of a slot without its date, e.g. "09:00–11:00".
String formatTimeRange(DateTime start, DateTime end) {
  String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  return '${time(start)}–${time(end)}';
}

/// US-11: human-readable audit time with the local UTC offset.
String formatSigningTime(DateTime timestamp) {
  final date = timestamp.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final offset = date.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${formatDate(date)} ${twoDigits(date.hour)}:${twoDigits(date.minute)} '
      '(UTC$sign${twoDigits(minutes ~/ 60)}:${twoDigits(minutes % 60)})';
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

/// US 23: a short summary of the criteria, e.g. "Sion · Rent · up to CHF 2'000".
String describeFilter(ApartmentFilter filter) {
  final parts = [
    if (filter.location.trim().isNotEmpty) filter.location.trim(),
    if (filter.listingType == ListingType.rent) 'Rent',
    if (filter.listingType == ListingType.sale) 'Buy',
    if (filter.minPrice != null) 'from ${formatChf(filter.minPrice!)}',
    if (filter.maxPrice != null) 'up to ${formatChf(filter.maxPrice!)}',
    if (filter.minRooms != null) '${filter.minRooms!.toInt()}+ rooms',
    if (filter.minSurface != null) '${filter.minSurface} m²+',
    for (final amenity in filter.amenities) amenity.label,
  ];
  return parts.isEmpty ? 'All apartments' : parts.join(' · ');
}
