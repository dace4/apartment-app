import '../models/apartment.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Apartments are not in Firebase yet: this service returns the sample
/// listings, with a short delay to behave like a real request.
class ApartmentService {
  final _collection = FirebaseFirestore.instance.collection('apartments');

  Future<List<Apartment>> getApartments() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => Apartment.fromMap(doc.id, doc.data())).toList();
  }

  /// Returns null when no apartment has this id.
  Future<Apartment?> getApartment(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) {
      return null;
    }
    return Apartment.fromMap(doc.id, doc.data()!);
  }

}
