import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appartment_app_group_2/app.dart';

void main() {
  testWidgets('starts on Apartments and switches tabs', (tester) async {
    await tester.pumpWidget(const HomeFlowApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Apartments'), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Services'), findsOneWidget);

    await tester.tap(find.text('Mortgage calculator'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Mortgage calculator'), findsOneWidget);
  });

  testWidgets('opens an apartment and its apply page', (tester) async {
    await tester.pumpWidget(const HomeFlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bright apartment near the old town'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Apartment 1'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Apply for apartment 1'),
      findsOneWidget,
    );

    // Back button returns to the apartment detail.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Apartment 1'), findsOneWidget);
  });
}
