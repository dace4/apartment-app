import '../../../shared/utils/formatters.dart';
import '../models/apartment.dart';

/// Price as shown to the user, e.g. "CHF 1'850 / month" or "CHF 890'000".
String formatApartmentPrice(Apartment apartment) =>
    switch (apartment.listingType) {
      ListingType.rent => '${formatChf(apartment.price)} / month',
      ListingType.sale => formatChf(apartment.price),
    };
