import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/view_models/market_trends_view_model.dart';
import 'package:appartment_app_group_2/views/services/market_trends_view.dart';

class ListingSource extends Fake implements ApartmentService {
  final controller = StreamController<List<Apartment>>.broadcast();
  @override
  Stream<List<Apartment>> watchApartments() => controller.stream;
}

Apartment listing(
  String id, {
  String city = 'Sion',
  int price = 600000,
  int surface = 100,
  ListingType type = ListingType.sale,
  ApartmentAvailability availability = ApartmentAvailability.available,
}) => Apartment(
  id: id,
  title: 'Apartment $id',
  address: 'Test address',
  city: city,
  listingType: type,
  price: price,
  rooms: 3,
  surface: surface,
  imageUrl: '',
  description: 'Test listing',
  availability: availability,
);

void main() {
  late ListingSource source;
  late MarketTrendsViewModel vm;
  setUp(() {
    source = ListingSource();
    vm = MarketTrendsViewModel(service: source);
  });
  tearDown(() async {
    vm.dispose();
    await source.controller.close();
  });
  Future<void> emit(List<Apartment> data) async {
    source.controller.add(data);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'statistics use sale listings and exclude unavailable or invalid entries',
    () async {
      vm.listenToApartments();
      expect(vm.isLoading, isTrue);
      await emit([
        listing('a', price: 600000, surface: 100),
        listing(
          'b',
          price: 900000,
          surface: 50,
          availability: ApartmentAvailability.reserved,
        ),
        listing('rental', type: ListingType.rent, price: 2000),
        listing('sold', availability: ApartmentAvailability.unavailable),
        listing('zero-surface', surface: 0),
        listing('zero-price', price: 0),
        listing('negative', surface: -1),
        listing('blank-city', city: '  '),
      ]);
      expect(vm.isLoading, isFalse);
      expect(vm.listingCount, 2);
      expect(vm.averagePrice, 750000);
      // Equal-weight average of 6000 and 18000, not total price / total area.
      expect(vm.averagePricePerSquareMetre, 12000);
      expect(vm.minimumPrice, 600000);
      expect(vm.maximumPrice, 900000);
    },
  );

  test('city filter and reset always use current source apartments', () async {
    vm.listenToApartments();
    await emit([listing('a'), listing('b', city: 'Martigny', price: 800000)]);
    expect(vm.cities, ['Martigny', 'Sion']);
    vm.selectCity('Martigny');
    expect(vm.apartments.single.id, 'b');
    expect(vm.averagePrice, 800000);
    vm.selectCity(null);
    expect(vm.listingCount, 2);
    vm.selectCity('Sion');
    await emit([listing('b', city: 'Martigny', price: 820000)]);
    expect(vm.selectedCity, isNull);
    expect(vm.averagePrice, 820000);
  });

  test(
    'live edits and removals recalculate; no invented history or fallback',
    () async {
      vm.listenToApartments();
      await emit([listing('a')]);
      expect(vm.averagePrice, 600000);
      await emit([listing('a', price: 650000)]);
      expect(vm.averagePrice, 650000);
      await emit([]);
      expect(vm.listingCount, 0);
      expect(vm.averagePrice, isNull);
      expect(vm.averagePricePerSquareMetre, isNull);
      expect(vm.minimumPrice, isNull);
      expect(vm.maximumPrice, isNull);
    },
  );

  test(
    'stream errors and retry recover; retry replaces its subscription',
    () async {
      vm.listenToApartments();
      source.controller.addError(Exception('permission denied'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.errorMessage, contains('Could not load'));
      expect(vm.isLoading, isFalse);
      vm.listenToApartments();
      expect(vm.errorMessage, isNull);
      await emit([listing('retry')]);
      expect(vm.listingCount, 1);
      expect(vm.errorMessage, isNull);
    },
  );

  test('disposal cancels the Firebase subscription', () async {
    final own = MarketTrendsViewModel(service: source);
    own.listenToApartments();
    expect(source.controller.hasListener, isTrue);
    own.dispose();
    expect(source.controller.hasListener, isFalse);
    await emit([listing('late')]);
  });

  testWidgets(
    'screen identifies its source, shows values and filters real listings',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MarketTrendsView(viewModel: vm)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.controller.add([
        listing('a'),
        listing('b', city: 'Martigny', price: 800000),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current sale listings'), findsOneWidget);
      expect(
        find.textContaining('Price history is not recorded'),
        findsOneWidget,
      );
      expect(find.text('Listings included: 2'), findsOneWidget);
      expect(find.text("Average asking price: CHF 700'000"), findsOneWidget);
      expect(find.textContaining('Illustrative'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Martigny').last);
      await tester.pumpAndSettle();
      expect(find.text('Listings included: 1'), findsOneWidget);
      expect(find.text("Average asking price: CHF 800'000"), findsOneWidget);
      expect(vm.apartments.single.id, 'b');
    },
  );

  testWidgets('source apartments open their existing detail route', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MarketTrendsView(viewModel: vm),
        ),
        GoRoute(
          path: '/apartments/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    source.controller.add([listing('a')]);
    await tester.pumpAndSettle();
    final tile = find.text('Apartment a');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Detail a'), findsOneWidget);
  });

  testWidgets('empty and error states show no fabricated prices; retry works', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: MarketTrendsView(viewModel: vm)));
    source.controller.add([]);
    await tester.pumpAndSettle();
    expect(
      find.text('No sale listings with valid price and surface data.'),
      findsOneWidget,
    );
    source.controller.addError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    source.controller.add([listing('recovered')]);
    await tester.pumpAndSettle();
    expect(find.text('Listings included: 1'), findsOneWidget);
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('screen fits at $width with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      source.controller.add([listing('a'), listing('b', city: 'Martigny')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
