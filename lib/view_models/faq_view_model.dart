import 'package:flutter/foundation.dart';

import '../models/faq_entry.dart';
import '../router/app_routes.dart';
import '../services/faq_service.dart';

/// US 14: searches the property FAQ and decides which links the user may
/// follow.
class FaqViewModel extends ChangeNotifier {
  /// [canAccess] is `AuthViewModel.canAccess`: a link is only offered when
  /// the user's roles allow the page it opens.
  /// [apartmentId] is set when the FAQ is opened from an apartment.
  FaqViewModel({required this.canAccess, this.apartmentId, FaqService? service})
    : _entries = (service ?? FaqService()).getEntries();

  final bool Function(String location) canAccess;
  final String? apartmentId;
  final List<FaqEntry> _entries;

  /// When opened from an apartment, the user can ask its advertiser a
  /// question the FAQ does not answer. null when there is no apartment or
  /// the user's roles do not allow contacting advertisers.
  String? get contactLocation {
    final id = apartmentId;
    if (id == null || id.isEmpty) return null;
    final location = AppRoutes.contactAdvertiser(id);
    return canAccess(location) ? location : null;
  }

  String query = '';

  /// null shows every category.
  FaqCategory? category;

  /// The categories that have at least one question, in enum order.
  List<FaqCategory> get categories => FaqCategory.values
      .where((value) => _entries.any((entry) => entry.category == value))
      .toList();

  /// The entries of the chosen category that match the search.
  List<FaqEntry> get visibleEntries => _entries
      .where((entry) => category == null || entry.category == category)
      .where((entry) => entry.matches(query))
      .toList();

  bool get hasFilters => query.trim().isNotEmpty || category != null;

  /// Shown when no entry matches, so the user knows why the list is empty.
  String get emptyMessage => query.trim().isEmpty
      ? 'No questions in this category yet.'
      : 'No questions match "${query.trim()}".';

  /// The page the entry links to, or null when it has no link or the
  /// user's roles do not allow that page.
  String? linkFor(FaqEntry entry) {
    final location = entry.linkLocation;
    if (location == null || entry.linkLabel == null) return null;
    return canAccess(location) ? location : null;
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  /// Selecting the chosen category again shows every category.
  void selectCategory(FaqCategory? value) {
    category = value == category ? null : value;
    notifyListeners();
  }

  void clearFilters() {
    query = '';
    category = null;
    notifyListeners();
  }
}
