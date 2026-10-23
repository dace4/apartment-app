import 'package:flutter/foundation.dart';

import '../models/apartment.dart';

/// US 13: the apartments chosen for the comparison, shared by the apartment
/// list, the apartment details and the Compare page (see ARCHITECTURE.md §4).
/// Kept in memory only: nothing is stored in Firebase.
class CompareViewModel extends ChangeNotifier {
  CompareViewModel({this.allowed = false});
  final bool allowed;
  static const maxApartments = 2;

  final List<Apartment> selected = [];

  bool isSelected(Apartment apartment) =>
      selected.any((item) => item.id == apartment.id);

  bool get isFull => selected.length >= maxApartments;

  bool get canCompare => selected.length == maxApartments;

  /// Adds the apartment, or removes it when it is already selected.
  /// Returns false when it could not be added because two are already chosen.
  bool toggle(Apartment apartment) {
    if (!allowed) return false;
    if (isSelected(apartment)) {
      remove(apartment);
      return true;
    }
    if (isFull) return false;

    selected.add(apartment);
    notifyListeners();
    return true;
  }

  void remove(Apartment apartment) {
    selected.removeWhere((item) => item.id == apartment.id);
    notifyListeners();
  }

  /// A monthly rent and a sale price cannot really be compared.
  bool get mixesRentAndSale =>
      canCompare && selected[0].listingType != selected[1].listingType;

  // Id of the apartment to highlight on each line, or null when both are equal.
  String? get cheaperId => _bestId((apartment) => -apartment.price);
  String? get cheaperPerSquareMetreId =>
      _bestId((apartment) => -apartment.pricePerSquareMetre);
  String? get biggerId => _bestId((apartment) => apartment.surface);
  String? get moreRoomsId => _bestId((apartment) => apartment.rooms);

  /// The id of the apartment with the highest [score].
  String? _bestId(num Function(Apartment apartment) score) {
    if (!canCompare) return null;
    final first = score(selected[0]);
    final second = score(selected[1]);
    if (first == second) return null;
    return first > second ? selected[0].id : selected[1].id;
  }
}
