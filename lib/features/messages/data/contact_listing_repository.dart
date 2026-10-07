import '../../apartments/data/sample_apartments.dart';
import '../models/advertiser_message.dart';

abstract class ContactListingRepository {
  const ContactListingRepository();

  /// Emits current contact information, or null when the property is removed.
  Stream<ContactListing?> watchListing(String id);
}

/// Uses the original sample apartments for the current app and tests. Sample
/// recipients are placeholders; the default message service does not send them.
class SampleContactListingRepository extends ContactListingRepository {
  const SampleContactListingRepository();

  @override
  Stream<ContactListing?> watchListing(String id) async* {
    final apartment = sampleApartments
        .where((item) => item.id == id)
        .firstOrNull;
    yield apartment == null
        ? null
        : ContactListing(
            id: id,
            title: apartment.title,
            advertiserId: 'sample-advertiser',
            advertiserName: 'Sample advertiser',
          );
  }
}
