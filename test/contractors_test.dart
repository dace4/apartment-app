import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/contractor.dart';
import 'package:appartment_app_group_2/services/contractor_service.dart';
import 'package:appartment_app_group_2/view_models/contractors_view_model.dart';
import 'package:appartment_app_group_2/views/services/contractors_view.dart';

class FakeContractorService extends ContractorService {
  FakeContractorService(this.load);
  final Future<List<Contractor>> Function() load;
  @override
  Future<List<Contractor>> getContractors() => load();
}

List<Contractor> fixtures() =>
    (jsonDecode(File('test/fixtures/contractors.json').readAsStringSync())
            as List)
        .map(
          (row) => Contractor.fromMap(
            row['id'] as String,
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();

void main() {
  test('seed directory contains six fictional entries across three cities', () {
    final entries = fixtures();
    expect(entries.length, 6);
    expect(entries.map((e) => e.id).toSet().length, 6);
    expect(entries.map((e) => e.city).toSet(), {
      'Lausanne',
      'Geneva',
      'Zurich',
    });
    for (final entry in entries) {
      expect(entry.email, endsWith('.example'));
      expect(entry.description, isNotEmpty);
      expect(Contractor.fromMap(entry.id, entry.toMap()).name, entry.name);
    }
  });

  test('city filtering, reset and no matches', () async {
    final vm = ContractorsViewModel(
      service: FakeContractorService(() async => fixtures()),
    );
    addTearDown(vm.dispose);
    await vm.fetchContractors();
    expect(vm.contractors.length, 6);
    expect(vm.cities, ['Geneva', 'Lausanne', 'Zurich']);
    vm.selectCity('Lausanne');
    expect(vm.contractors.length, 2);
    expect(vm.contractors.every((c) => c.city == 'Lausanne'), isTrue);
    vm.selectCity('Missing city');
    expect(vm.contractors, isEmpty);
    vm.selectCity(null);
    expect(vm.contractors.length, 6);
  });

  test('loading, error and successful retry; no bundled fallback', () async {
    var fail = true;
    final pending = Completer<List<Contractor>>();
    final vm = ContractorsViewModel(
      service: FakeContractorService(
        () => fail ? Future.error(Exception('offline')) : pending.future,
      ),
    );
    addTearDown(vm.dispose);
    await vm.fetchContractors();
    expect(vm.errorMessage, contains('Firebase'));
    expect(vm.contractors, isEmpty);
    fail = false;
    final request = vm.fetchContractors();
    expect(vm.isLoading, isTrue);
    pending.complete(fixtures());
    await request;
    expect(vm.isLoading, isFalse);
    expect(vm.errorMessage, isNull);
    expect(vm.contractors.length, 6);
  });

  test('request can finish safely after leaving the screen', () async {
    final pending = Completer<List<Contractor>>();
    final vm = ContractorsViewModel(
      service: FakeContractorService(() => pending.future),
    );
    final request = vm.fetchContractors();
    vm.dispose();
    pending.complete(fixtures());
    await request;
  });

  testWidgets(
    'directory displays sample contacts and city selection updates results',
    (tester) async {
      final vm = ContractorsViewModel(
        service: FakeContractorService(() async => fixtures()),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ContractorsView(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Find renovation contractors by city and trade.'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsWidgets);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lausanne').last);
      await tester.pumpAndSettle();
      expect(find.text('Lausanne Wood Workshop'), findsOneWidget);
      expect(find.text('Geneva Floor Workshop'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All cities').last);
      await tester.pumpAndSettle();
      expect(vm.contractors.length, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty Firebase catalogue displays an empty state', (
    tester,
  ) async {
    final vm = ContractorsViewModel(
      service: FakeContractorService(() async => []),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(home: ContractorsView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.text('No contractors found.'), findsOneWidget);
    expect(
      find.text('Find renovation contractors by city and trade.'),
      findsOneWidget,
    );
  });

  testWidgets('Firebase failure offers retry', (tester) async {
    var fail = true;
    final vm = ContractorsViewModel(
      service: FakeContractorService(() async {
        if (fail) throw Exception('permission-denied');
        return fixtures();
      }),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(home: ContractorsView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Find renovation contractors by city and trade.'),
      findsOneWidget,
    );
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('screen fits at $width with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = ContractorsViewModel(
        service: FakeContractorService(() async => fixtures()),
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ContractorsView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
