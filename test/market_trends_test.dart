import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/market_price.dart';
import 'package:appartment_app_group_2/services/market_trends_service.dart';
import 'package:appartment_app_group_2/view_models/market_trends_view_model.dart';
import 'package:appartment_app_group_2/views/services/market_trends_view.dart';

class FakeMarketTrendsService extends MarketTrendsService {
  FakeMarketTrendsService(this.load);
  final Future<List<MarketPrice>> Function() load;
  @override
  Future<List<MarketPrice>> getPrices() => load();
}

List<MarketPrice> fixtures() =>
    (jsonDecode(File('test/fixtures/market_trends.json').readAsStringSync())
            as List)
        .map((row) => MarketPrice.fromMap(Map<String, dynamic>.from(row)))
        .toList();

void main() {
  test('Firebase seed has six monthly prices for each city', () {
    final entries = fixtures();
    expect(entries.length, 18);
    for (final city in ['Lausanne', 'Geneva', 'Zurich']) {
      final prices = entries.where((p) => p.city == city).toList();
      expect(prices.length, 6);
      expect(prices.map((p) => p.month.month), [4, 5, 6, 7, 8, 9]);
      expect(prices.every((p) => p.pricePerSquareMetre > 0), isTrue);
    }
    final first = entries.first;
    expect(MarketPrice.fromMap(first.toMap()).month, first.month);
  });

  test('selecting a city changes latest price and six-month period', () async {
    final vm = MarketTrendsViewModel(
      service: FakeMarketTrendsService(
        () async => fixtures().reversed.toList(),
      ),
    );
    addTearDown(vm.dispose);
    await vm.fetchPrices();
    expect(vm.selectedCity, 'Geneva');
    expect(vm.latestPrice, 14800);
    vm.selectCity('Zurich');
    expect(vm.prices.length, 6);
    expect(vm.latestPrice, 16300);
    expect(vm.periodLabel, 'April 2026 – September 2026');
    expect(vm.percentageChange, closeTo(1.875, 0.00001));
    expect(vm.changeLabel, '+1.9% over this period');
  });

  for (final last in [11000, 10000, 9000]) {
    test('percentage calculation from 10000 to $last', () async {
      final vm = MarketTrendsViewModel(
        service: FakeMarketTrendsService(
          () async => [
            MarketPrice(
              city: 'Test',
              month: DateTime(2026, 4),
              pricePerSquareMetre: 10000,
            ),
            MarketPrice(
              city: 'Test',
              month: DateTime(2026, 9),
              pricePerSquareMetre: last,
            ),
          ],
        ),
      );
      addTearDown(vm.dispose);
      await vm.fetchPrices();
      expect(vm.percentageChange, (last - 10000) / 10000 * 100);
      expect(
        vm.changeLabel,
        last == 11000
            ? '+10.0% over this period'
            : last == 10000
            ? '0.0% over this period'
            : '-10.0% over this period',
      );
    });
  }

  test('zero baseline and missing data do not invent a change', () async {
    final vm = MarketTrendsViewModel(
      service: FakeMarketTrendsService(
        () async => [
          MarketPrice(
            city: 'Test',
            month: DateTime(2026, 4),
            pricePerSquareMetre: 0,
          ),
          MarketPrice(
            city: 'Test',
            month: DateTime(2026, 9),
            pricePerSquareMetre: 10000,
          ),
        ],
      ),
    );
    addTearDown(vm.dispose);
    await vm.fetchPrices();
    expect(vm.percentageChange, isNull);
    vm.selectCity('Unknown');
    expect(vm.prices, isEmpty);
    expect(vm.latestPrice, isNull);
    expect(vm.changeLabel, 'Change unavailable');
  });

  test('loading, failure, retry and disposal while loading', () async {
    var fail = true;
    final pending = Completer<List<MarketPrice>>();
    final vm = MarketTrendsViewModel(
      service: FakeMarketTrendsService(
        () => fail ? Future.error(Exception('offline')) : pending.future,
      ),
    );
    await vm.fetchPrices();
    expect(vm.errorMessage, contains('Firebase'));
    expect(vm.prices, isEmpty);
    fail = false;
    final request = vm.fetchPrices();
    expect(vm.isLoading, isTrue);
    vm.dispose();
    pending.complete(fixtures());
    await request;
  });

  testWidgets(
    'city selector updates illustrative latest price and monthly list',
    (tester) async {
      final vm = MarketTrendsViewModel(
        service: FakeMarketTrendsService(() async => fixtures()),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(home: MarketTrendsView(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Illustrative data'), findsOneWidget);
      expect(find.text("Latest sample price: CHF 14'800 / m²"), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zurich').last);
      await tester.pumpAndSettle();
      expect(find.text("Latest sample price: CHF 16'300 / m²"), findsOneWidget);
      expect(find.text('+1.9% over this period'), findsOneWidget);
      expect(find.text('April 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty collection and failure are distinct from sample prices', (
    tester,
  ) async {
    var fail = true;
    final vm = MarketTrendsViewModel(
      service: FakeMarketTrendsService(() async {
        if (fail) throw Exception('offline');
        return [];
      }),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(home: MarketTrendsView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No market trends available.'), findsOneWidget);
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('screen fits at $width with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = MarketTrendsViewModel(
        service: FakeMarketTrendsService(() async => fixtures()),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: MarketTrendsView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
