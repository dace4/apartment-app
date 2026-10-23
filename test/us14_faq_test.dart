import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/models/faq_entry.dart';
import 'package:appartment_app_group_2/router/app_routes.dart';
import 'package:appartment_app_group_2/services/faq_service.dart';
import 'package:appartment_app_group_2/view_models/faq_view_model.dart';
import 'package:appartment_app_group_2/views/profile/faq_view.dart';

bool allowAll(String location) => true;

void main() {
  group('US-14 FAQ content', () {
    test('every entry has an id, a question and an answer', () {
      final entries = FaqService().getEntries();
      expect(entries.length, greaterThanOrEqualTo(10));
      expect(entries.map((e) => e.id).toSet().length, entries.length);
      for (final entry in entries) {
        expect(entry.question.trim(), isNotEmpty);
        expect(entry.answer.trim(), isNotEmpty);
        // A link always has both a label and a page.
        expect(entry.linkLabel == null, entry.linkLocation == null);
      }
    });

    test('links only point to pages of the app', () {
      const known = {
        AppRoutes.apartments,
        AppRoutes.createApartment,
        AppRoutes.compare,
        AppRoutes.applications,
        AppRoutes.documents,
        AppRoutes.visits,
        AppRoutes.savedSearches,
        AppRoutes.notifications,
        AppRoutes.inbox,
        AppRoutes.maintenance,
        AppRoutes.mortgage,
        AppRoutes.profile,
      };
      for (final entry in FaqService().getEntries()) {
        if (entry.linkLocation != null) {
          expect(known, contains(entry.linkLocation), reason: entry.id);
        }
      }
    });
  });

  group('US-14 FaqViewModel', () {
    test('search matches questions and answers, ignoring case', () {
      final viewModel = FaqViewModel(canAccess: allowAll);

      viewModel.search('DEPOSIT');
      expect(viewModel.visibleEntries.map((e) => e.id), contains('deposit'));

      viewModel.search('700 KiB'); // only in an answer
      expect(viewModel.visibleEntries.map((e) => e.id), ['documents']);
    });

    test(
      'a category shows only its questions; selecting it again shows all',
      () {
        final viewModel = FaqViewModel(canAccess: allowAll);
        final total = viewModel.visibleEntries.length;

        viewModel.selectCategory(FaqCategory.visits);
        expect(
          viewModel.visibleEntries.every(
            (e) => e.category == FaqCategory.visits,
          ),
          isTrue,
        );

        viewModel.selectCategory(FaqCategory.visits);
        expect(viewModel.category, isNull);
        expect(viewModel.visibleEntries.length, total);
      },
    );

    test('no match gives an empty list, a message and a way to clear', () {
      final viewModel = FaqViewModel(canAccess: allowAll);

      viewModel.search('helicopter');
      expect(viewModel.visibleEntries, isEmpty);
      expect(viewModel.emptyMessage, 'No questions match "helicopter".');
      expect(viewModel.hasFilters, isTrue);

      viewModel.clearFilters();
      expect(viewModel.visibleEntries, isNotEmpty);
      expect(viewModel.hasFilters, isFalse);
    });

    test('links to pages the roles do not allow are hidden', () {
      final viewModel = FaqViewModel(
        canAccess: (location) => location != AppRoutes.maintenance,
      );
      final maintenance = FaqService.entries.firstWhere(
        (e) => e.id == 'maintenance',
      );
      final apply = FaqService.entries.firstWhere((e) => e.id == 'apply');

      expect(viewModel.linkFor(maintenance), isNull);
      expect(viewModel.linkFor(apply), AppRoutes.applications);
    });

    test('opened from an apartment, offers to contact its advertiser', () {
      expect(
        FaqViewModel(canAccess: allowAll, apartmentId: 'a1').contactLocation,
        AppRoutes.contactAdvertiser('a1'),
      );
      expect(FaqViewModel(canAccess: allowAll).contactLocation, isNull);
      expect(
        FaqViewModel(
          canAccess: (location) => !location.endsWith('/contact'),
          apartmentId: 'a1',
        ).contactLocation,
        isNull,
      );
    });
  });

  group('US-14 FaqView', () {
    testWidgets('shows the questions and the empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FaqView(canAccess: allowAll)),
      );

      expect(
        find.text('How do I find an apartment that suits me?'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'helicopter');
      await tester.pump();
      expect(find.text('No questions match "helicopter".'), findsOneWidget);

      await tester.tap(find.text('Show all questions'));
      await tester.pump();
      expect(
        find.text('How do I find an apartment that suits me?'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a question shows its answer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FaqView(canAccess: allowAll)),
      );

      await tester.tap(find.text('How do I find an apartment that suits me?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Open the Home tab'), findsOneWidget);
      expect(find.text('Browse apartments'), findsOneWidget);
    });
  });
}
