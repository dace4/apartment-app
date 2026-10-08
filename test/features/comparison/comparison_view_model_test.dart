import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/features/apartments/models/apartment.dart';
import 'package:appartment_app_group_2/features/comparison/view_models/comparison_view_model.dart';

//simple test for only id & listing type
Apartment _apartment(String id, {ListingType type = ListingType.rent}) =>
    Apartment(
      id: id,
      title: 'Apartment $id',
      address: 'Rue du Test 1',
      city: 'Sion',
      listingType: type,
      price: 1500,
      rooms: 3.5,
      surface: 80,
      imageUrl: '',
      description: '',
    );
void main() {
  late ComparisonViewModel viewModel;
  setUp(() {
    viewModel = ComparisonViewModel();
  });

  test('starts with no apartment selected', () {
    expect(viewModel.count, 0);
    expect(viewModel.canCompare, isFalse);
  });

  test('selects up to 2 apartment', () {
    expect(viewModel.toggle(_apartment('a')), SelectionResult.added);
    expect(viewModel.toggle(_apartment('b')), SelectionResult.added);

    expect(viewModel.count, 2);
    expect(viewModel.canCompare, isTrue);
  });

  test('refuse a third apartment', () {
    viewModel.toggle(_apartment('a'));
    viewModel.toggle(_apartment('b'));

    expect(viewModel.toggle(_apartment('c')), SelectionResult.limitReached);
    expect(viewModel.count, 2);
  });

  test('tapping a selected apartment removes it', () {
    viewModel.toggle(_apartment('a'));

    expect(viewModel.toggle(_apartment('a')), SelectionResult.removed);
    expect(viewModel.isSelected(_apartment('a')), isFalse);
    expect(viewModel.count, 0);
  });

  test('refuses mixing rent and sales apartments', () {
    viewModel.toggle(_apartment('a'));

    expect(
      viewModel.toggle(_apartment('b', type: ListingType.sale)),
      SelectionResult.differentListingType,
    );
    expect(viewModel.count, 1);
  });

  test('clear removes all selected apartments', () {
    viewModel.toggle(_apartment('a'));
    viewModel.toggle(_apartment('b'));

    viewModel.clear();

    expect(viewModel.count, 0);
  });
}
