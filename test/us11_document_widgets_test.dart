import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/signing_document.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';
import 'package:appartment_app_group_2/views/documents/document_review_view.dart';
import 'package:appartment_app_group_2/views/documents/widgets/signature_pad.dart';

void main() {
  setUpAll(() async {
    // Optional local captures use actual SDK fonts, never Flutter's Ahem test font.
    const fonts = String.fromEnvironment('US11_FONT_DIR');
    if (!const bool.fromEnvironment('US11_CAPTURE') || fonts.isEmpty) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File('$fonts/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  for (final width in [360.0, 800.0]) {
    testWidgets('US-11 review and drawn signing at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final document = SigningDocument(
        id: 'lease',
        userId: 'tenant',
        title: 'Rental agreement',
        body:
            'Apartment: 24 Garden Street\n\n'
            'Monthly rent: CHF 1,800\n\n'
            'The tenant confirms receipt of the rental terms and the apartment inventory. '
            'This is a sample document used only for local US-11 tests.',
        version: 1,
        issuedAt: DateTime.utc(2026, 10, 13),
      );
      await db
          .collection('signingDocuments')
          .doc('lease')
          .set(document.toMap());
      final vm = DocumentReviewViewModel(
        service: DocumentService(
          firestore: db,
          currentUser: () => const AppUser(
            id: 'tenant',
            email: 'tenant@example.test',
            emailVerified: true,
          ),
        ),
      );
      addTearDown(vm.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            ),
            home: DocumentReviewView(documentId: 'lease', viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apartment: 24 Garden Street'),
        findsOneWidget,
      );
      final submit = find.widgetWithText(FilledButton, 'Sign and save');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      Future<void> capture(String suffix) async {
        if (!const bool.fromEnvironment('US11_CAPTURE')) return;
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '.dart_tool/us11-review/${width.toInt()}-$suffix.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('review');
      final review = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Taylor Tenant');
      final pad = find.byType(SignaturePad);
      await tester.ensureVisible(pad);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(pad);
      final gesture = await tester.startGesture(
        Offset(bounds.left + 30, bounds.top + 40),
      );
      await gesture.moveBy(const Offset(60, 40));
      await gesture.moveBy(const Offset(60, -25));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(vm.signature.hasInk, isTrue);
      final consent = find.byType(CheckboxListTile).last;
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await capture('capture');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Signed and saved'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect((await db.collection('signedDocuments').get()).docs, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
      await capture('signed');
      // Large text must stay readable without horizontal overflow.
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DocumentReviewView(documentId: 'lease', viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('large-text');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
