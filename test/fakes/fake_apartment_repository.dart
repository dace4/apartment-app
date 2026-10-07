import 'dart:async';

import 'package:appartment_app_group_2/features/apartments/data/apartment_repository.dart';
import 'package:appartment_app_group_2/features/apartments/models/apartment.dart';
import 'package:appartment_app_group_2/features/apartments/data/sample_apartments.dart';

class FakeApartmentRepository extends ApartmentRepository {
  FakeApartmentRepository({List<Apartment> initial = sampleApartments})
    : current = List.of(initial),
      super(delay: Duration.zero);

  List<Apartment> current;
  final _updates = StreamController<List<Apartment>>.broadcast();
  bool failRefresh = false;
  int refreshes = 0;
  List<Apartment>? onRefresh;

  @override
  Stream<List<Apartment>> watchApartments() async* {
    yield List.of(current);
    yield* _updates.stream;
  }

  @override
  Stream<Apartment?> watchApartment(String id) => watchApartments().map(
    (list) => list.where((apartment) => apartment.id == id).firstOrNull,
  );

  @override
  Future<List<Apartment>> fetchApartments() async {
    refreshes++;
    if (failRefresh) throw StateError('Refresh failed');
    if (onRefresh != null) emit(onRefresh!);
    return List.of(current);
  }

  @override
  Future<Apartment?> fetchApartment(String id) async =>
      (await fetchApartments())
          .where((apartment) => apartment.id == id)
          .firstOrNull;

  void emit(List<Apartment> apartments) {
    current = List.of(apartments);
    _updates.add(List.of(current));
  }

  void failStream() => _updates.addError(StateError('Connection lost'));
  Future<void> dispose() => _updates.close();
}
