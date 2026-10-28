import 'package:flutter/foundation.dart';

import '../models/market_price.dart';
import '../services/market_trends_service.dart';

class MarketTrendsViewModel extends ChangeNotifier {
  MarketTrendsViewModel({MarketTrendsService? service})
    : _service = service ?? MarketTrendsService();

  final MarketTrendsService _service;
  List<MarketPrice> _prices = const [];
  String? selectedCity;
  bool isLoading = false;
  String? errorMessage;
  bool _disposed = false;

  List<String> get cities =>
      _prices.map((p) => p.city).toSet().toList()..sort();
  List<MarketPrice> get prices =>
      _prices.where((p) => p.city == selectedCity).toList()
        ..sort((a, b) => a.month.compareTo(b.month));
  int? get latestPrice =>
      prices.isEmpty ? null : prices.last.pricePerSquareMetre;
  String get periodLabel => prices.isEmpty
      ? ''
      : '${prices.first.monthLabel} – ${prices.last.monthLabel}';

  double? get percentageChange {
    final values = prices;
    if (values.length < 2 || values.first.pricePerSquareMetre <= 0) return null;
    return (values.last.pricePerSquareMetre -
            values.first.pricePerSquareMetre) /
        values.first.pricePerSquareMetre *
        100;
  }

  String get changeLabel {
    final change = percentageChange;
    if (change == null) return 'Change unavailable';
    final rounded = change.toStringAsFixed(1);
    if (rounded == '0.0' || rounded == '-0.0') return '0.0% over this period';
    return '${change > 0 ? '+' : ''}$rounded% over this period';
  }

  Future<void> fetchPrices() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final entries = await _service.getPrices();
      if (_disposed) return;
      _prices = List.unmodifiable(entries);
      if (!cities.contains(selectedCity)) selectedCity = cities.firstOrNull;
    } catch (_) {
      if (_disposed) return;
      errorMessage = 'Could not load market trends from Firebase. Check your connection and try again.';
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
