import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/services/signature_service.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/view_models/signature_view_model.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';
import 'package:appartment_app_group_2/views/signatures/signature_view.dart';
import 'package:appartment_app_group_2/views/signatures/widgets/signature_pad.dart';
import 'package:appartment_app_group_2/views/documents/document_review_view.dart';

import 'us15_documents_test.dart' as fixtures;
import 'us11_signing_test.dart' show drawing;

void main() {
  testWidgets('US-11 long filename and actions fit compact enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    final service = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    await tester.runAsync(() => service.upload(fixtures.jpegUpload('photo')));
    final name = '${'a' * 196}.jpg';
    await db.collection('uploadedDocuments').doc('photo').update({
      'name': name,
    });
    final vm = DocumentReviewViewModel(
      canAccess: () => true,
      service: service,
      signatureService: SignatureService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      ),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: DocumentReviewView(documentId: 'photo', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(name)).maxLines, 2);
    await tester.ensureVisible(find.text('Remove document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove document'));
    await tester.pumpAndSettle();
    expect(find.text('Remove document?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [360.0, 800.0]) {
    testWidgets('US-11 draw, save and replace under the same ID at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final service = SignatureService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      );
      final vm = SignatureViewModel(canAccess: () => true, service: service);
      addTearDown(vm.dispose);
      await tester.pumpWidget(MaterialApp(home: SignatureView(viewModel: vm)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save signature'),
            )
            .onPressed,
        isNull,
      );
      final pad = find.byType(SignaturePad);
      await tester.drag(pad, const Offset(100, 30));
      await tester.pumpAndSettle();
      expect(vm.canSave, isTrue);
      await tester.tap(find.text('Save signature'));
      await tester.pumpAndSettle();
      expect(find.text('Signature saved.'), findsOneWidget);
      final id = vm.savedSignature!.id;
      await tester.tap(find.text('Clear drawing'));
      await tester.pumpAndSettle();
      await tester.drag(pad, const Offset(80, -40));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace signature'));
      await tester.pumpAndSettle();
      expect(vm.savedSignature!.id, id);
      expect((await db.collection('userSignatures').get()).docs, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'US-11 confirmation cancels without changes; confirm hides Bind and removal',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = DocumentService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      );
      final signatures = SignatureService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      );
      await tester.runAsync(() => service.upload(fixtures.jpegUpload('photo')));
      await signatures.save(drawing());
      final vm = DocumentReviewViewModel(
        canAccess: () => true,
        service: service,
        signatureService: signatures,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentReviewView(documentId: 'photo', viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bind signature'));
      await tester.pumpAndSettle();
      expect(find.textContaining('photo.jpg'), findsNWidgets(2));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await service.getDocument('photo'))!.isSigned, isFalse);
      await tester.tap(find.text('Bind signature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm and sign'));
      await tester.pumpAndSettle();
      expect(find.text('Bind signature'), findsNothing);
      expect(find.text('Remove document'), findsNothing);
      expect(find.text('Signed'), findsOneWidget);
      expect(find.byType(SignaturePad), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('US-11 no saved signature disables Bind with setup guidance', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    await tester.runAsync(() => service.upload(fixtures.jpegUpload('photo')));
    final vm = DocumentReviewViewModel(
      canAccess: () => true,
      service: service,
      signatureService: SignatureService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      ),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentReviewView(documentId: 'photo', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Bind signature'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Set up My Signature before signing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
