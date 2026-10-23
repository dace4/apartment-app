import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/apartment_filter.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/utils/formatters.dart';
import 'package:appartment_app_group_2/view_models/apartments_view_model.dart';

class FakeApartmentService extends Fake implements ApartmentService {}

const sion = Apartment(
  id: '1',
  title: 'Flat in Sion',
  address: 'Rue 1',
  city: '1950 Sion',
  listingType: ListingType.rent,
  price: 1500,
  rooms: 3,
  surface: 70,
  imageUrl: '',
  description: '',
  availability: ApartmentAvailability.available,
);

void main() {
  late ApartmentsViewModel viewModel;

  setUp(() {
    viewModel = ApartmentsViewModel(service: FakeApartmentService())
      ..apartments = [sion];
  });

  test('the header text lists the selected filter values', () {
    const filter = ApartmentFilter(
      location: 'Sion',
      listingType: ListingType.rent,
      maxPrice: 2000,
    );
    expect(describeFilter(filter), contains('Sion'));
    expect(describeFilter(filter), contains('Rent'));
    expect(describeFilter(filter), contains('up to'));
  });

  test('no apartment matches: the list is empty and filters are active', () {
    viewModel.applyFilter(const ApartmentFilter(location: 'Zurich'));

    expect(viewModel.visibleApartments, isEmpty);
    expect(viewModel.hasFilters, isTrue);
  });

  test('clearing the filters shows every apartment again', () {
    viewModel.applyFilter(const ApartmentFilter(location: 'Zurich'));
    viewModel.selectAvailability(ApartmentAvailability.reserved);

    viewModel.clearFilters();

    expect(viewModel.filter.isEmpty, isTrue);
    expect(viewModel.availability, isNull);
    expect(viewModel.visibleApartments, [sion]);
  });
}
