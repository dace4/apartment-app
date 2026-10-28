import 'package:flutter/foundation.dart';

import '../models/contractor.dart';
import '../services/contractor_service.dart';

class ContractorsViewModel extends ChangeNotifier {
  ContractorsViewModel({ContractorService? service})
    : _service = service ?? ContractorService();

  final ContractorService _service;
  List<Contractor> _contractors = const [];
  String? selectedCity;
  bool isLoading = false;
  String? errorMessage;
  bool _disposed = false;

  List<String> get cities =>
      _contractors.map((c) => c.city).toSet().toList()..sort();
  List<Contractor> get contractors => _contractors
      .where((c) => selectedCity == null || c.city == selectedCity)
      .toList();

  Future<void> fetchContractors() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final entries = await _service.getContractors();
      if (_disposed) return;
      _contractors = List.unmodifiable(
        [...entries]..sort((a, b) => a.name.compareTo(b.name)),
      );
      if (!cities.contains(selectedCity)) selectedCity = null;
    } catch (_) {
      if (_disposed) return;
      errorMessage = 'Could not load contractors from Firebase. Check your connection and try again.';
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectCity(String? city) {
    selectedCity = city;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
