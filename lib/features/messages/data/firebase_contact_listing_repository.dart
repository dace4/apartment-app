import 'package:cloud_firestore/cloud_firestore.dart';

import '../../apartments/data/apartment_repository.dart';
import '../models/advertiser_message.dart';
import 'contact_listing_repository.dart';

/// US 12: joins the existing apartment with its separately administered contact.
class FirebaseContactListingRepository extends ContactListingRepository {
  FirebaseContactListingRepository(
    this.firestore, {
    this.apartmentRepository = const ApartmentRepository(),
    this.refreshSession,
  });
  final FirebaseFirestore firestore;
  final ApartmentRepository apartmentRepository;
  final Future<void> Function()? refreshSession;

  @override
  Stream<ContactListing?> watchListing(String id) async* {
    final apartment = await apartmentRepository.fetchApartment(id);
    if (apartment == null) {
      yield null;
      return;
    }
    try {
      await refreshSession?.call();
    } on FirebaseException catch (error) {
      // Offline contact information can be viewed, but sending requires the server.
      if (error.code != 'network-request-failed') rethrow;
    }
    yield* firestore.collection('advertiserContacts').doc(id).snapshots().map((
      doc,
    ) {
      // Missing or malformed contact data disables sending without pretending
      // that the sample apartment has disappeared or inventing a recipient.
      final data = doc.data();
      return ContactListing(
        id: id,
        title: apartment.title,
        advertiserId: data?['advertiserId'] is String
            ? data!['advertiserId'] as String
            : '',
        advertiserName: data?['advertiserName'] is String
            ? data!['advertiserName'] as String
            : '',
      );
    });
  }
}
