import 'package:appartment_app_group_2/features/apartments/data/sample_apartments.dart';
import 'package:appartment_app_group_2/features/apartments/models/apartment.dart';
import 'package:appartment_app_group_2/features/apartments/pages/apartment_detail_page.dart';
import 'package:appartment_app_group_2/features/apartments/pages/apartment_list_page.dart';
import 'package:appartment_app_group_2/features/apartments/widgets/apartment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_apartment_repository.dart';

void main() {
  late FakeApartmentRepository repository;
  setUp(() => repository = FakeApartmentRepository());
  tearDown(() => repository.dispose());

  Future<void> list(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ApartmentListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> detail(WidgetTester tester, String id) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ApartmentDetailPage(apartmentId: id, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('filters each status without removing other listings', (
    tester,
  ) async {
    await list(tester);
    for (final status in ApartmentAvailability.values) {
      await tester.tap(find.widgetWithText(ChoiceChip, status.label));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<ApartmentCard>(
        find.byType(ApartmentCard),
      );
      expect(cards, isNotEmpty);
      expect(
        cards.every((card) => card.apartment.availability == status),
        isTrue,
      );
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text(sampleApartments.first.title), findsOneWidget);
    expect(repository.current.length, sampleApartments.length);
  });

  testWidgets('live updates reapply the selected filter', (tester) async {
    repository.emit([sampleApartments.first]);
    await list(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Available'));
    repository.emit([
      sampleApartments.first.copyWith(
        availability: ApartmentAvailability.reserved,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('No results found.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reserved'));
    await tester.pumpAndSettle();
    expect(find.text(sampleApartments.first.title), findsOneWidget);
  });

  testWidgets('refresh loads the latest status and preserves filtering', (
    tester,
  ) async {
    repository.emit([sampleApartments.first]);
    repository.onRefresh = [
      sampleApartments.first.copyWith(
        availability: ApartmentAvailability.reserved,
      ),
    ];
    await list(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Available'));
    await tester.tap(find.byTooltip('Refresh availability'));
    await tester.pumpAndSettle();
    expect(repository.refreshes, 1);
    expect(find.text('No results found.'), findsOneWidget);
  });

  testWidgets('refresh errors are visible and existing listings survive', (
    tester,
  ) async {
    repository.failRefresh = true;
    await list(tester);
    await tester.tap(find.byTooltip('Refresh availability'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not refresh availability. Please try again.'),
      findsOneWidget,
    );
    expect(find.text(sampleApartments.first.title), findsOneWidget);
  });

  for (final status in ApartmentAvailability.values) {
    testWidgets(
      '${status.label} details show the status and correct Apply action',
      (tester) async {
        repository.emit([
          sampleApartments.first.copyWith(availability: status),
        ]);
        await detail(tester, '1');
        expect(find.text(status.label), findsOneWidget);
        await tester.ensureVisible(find.text('Apply'));
        expect(
          tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Apply'),
                  )
                  .onPressed !=
              null,
          status == ApartmentAvailability.available,
        );
      },
    );
  }

  testWidgets('an open detail reacts to reservation and removal', (
    tester,
  ) async {
    await detail(tester, '1');
    repository.emit([
      sampleApartments.first.copyWith(
        availability: ApartmentAvailability.reserved,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Reserved'), findsOneWidget);
    repository.emit([]);
    await tester.pumpAndSettle();
    expect(
      find.text('This apartment does not exist or is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('stream error hides stale data and Retry reconnects', (
    tester,
  ) async {
    await list(tester);
    repository.failStream();
    await tester.pumpAndSettle();
    expect(find.text('Could not load the apartments.'), findsOneWidget);
    expect(find.byType(ApartmentCard), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text(sampleApartments.first.title), findsOneWidget);
  });
}
