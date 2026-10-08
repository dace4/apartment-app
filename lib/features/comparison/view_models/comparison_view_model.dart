import 'package:flutter/foundation.dart';

import '../../apartments/models/apartment.dart';

/// The result of a selection action in the comparison view.
enum SelectionResult { added, removed, limitReached, differentListingType }

//US13: remember which apa the user picked to compare (max 2)
class ComparisonViewModel extends ChangeNotifier {
  static const int maxSelection = 2;

  final List<Apartment> _selected = [];

  List<Apartment> get selected => List.unmodifiable(_selected);
  int get count => _selected.length;
  bool get canCompare => _selected.length == maxSelection;

  bool isSelected(Apartment apartment) =>
      _selected.any((a) => a.id == apartment.id);

  SelectionResult toggle(Apartment apartment) {
    if (isSelected(apartment)) {
      _selected.removeWhere((a) => a.id == apartment.id);
      notifyListeners();
      return SelectionResult.removed;
    }
    if (_selected.length >= maxSelection) {
      return SelectionResult.limitReached;
    }
    if (_selected.isNotEmpty &&
        _selected.first.listingType != apartment.listingType) {
      return SelectionResult.differentListingType;
    }
    _selected.add(apartment);
    notifyListeners();
    return SelectionResult.added;
  }

  void clear() {
    _selected.clear();
    notifyListeners();
  }
}
