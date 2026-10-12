import '../models/apartment.dart';
import 'sample_apartments.dart';

/// Apartments are not in Firebase yet: this service returns the sample
/// listings, with a short delay to behave like a real request.
class ApartmentService {
  Future<List<Apartment>> getApartments() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return sampleApartments;
  }

  /// Returns null when no apartment has this id.
  Future<Apartment?> getApartment(String id) async {
    final apartments = await getApartments();
    return apartments.where((apartment) => apartment.id == id).firstOrNull;
  }
}
