import '../models/apartment.dart';
import 'sample_apartments.dart';

class ApartmentRepository {
  const ApartmentRepository({
    this.apartments = sampleApartments,
    this.delay = const Duration(milliseconds: 800),
  });

  final List<Apartment> apartments;
  final Duration delay;

  // US 8: sample reads emit once; pages keep their filter when reconnecting
  // these streams after an availability refresh.
  Stream<List<Apartment>> watchApartments() =>
      Stream.fromFuture(fetchApartments());

  Stream<Apartment?> watchApartment(String id) =>
      Stream.fromFuture(fetchApartment(id));

  //a "promise" of value, we don't have the list for the moment but they give you that later
  Future<List<Apartment>> fetchApartments() async {
    await Future.delayed(delay);
    return apartments;
  }

  Future<Apartment?> fetchApartment(String id) async {
    await Future.delayed(delay);
    for (final apartment in apartments) {
      if (apartment.id == id) return apartment;
    }
    return null;
  }
}
