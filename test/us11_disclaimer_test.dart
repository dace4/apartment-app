import 'dart:async';

import 'package:appartment_app_group_2/models/uploaded_document.dart';
import 'package:appartment_app_group_2/services/document_exception.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/services/signature_service.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';
import 'package:appartment_app_group_2/views/documents/document_review_view.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'us11_signing_test.dart' show drawing;
import 'us15_documents_test.dart' as fixtures;

const disclaimer =
    'This signed document is certified and cannot be changed after it has been signed.';

class ControlledBindingService extends DocumentService {
  ControlledBindingService(FakeFirebaseFirestore db)
    : super(firestore: db, currentUser: () => fixtures.tenant);

  final result = Completer<UploadedDocument>();

  @override
  Future<UploadedDocument> bindSignature(String id) => result.future;
}

void main() {
  late FakeFirebaseFirestore db;
  late DocumentService documents;
  late SignatureService signatures;

  setUp(() async {
    db = FakeFirebaseFirestore();
    documents = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    signatures = SignatureService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    await signatures.save(drawing());
  });

  DocumentReviewViewModel createViewModel([DocumentService? service]) {
    final vm = DocumentReviewViewModel(
      canAccess: () => true,
      service: service ?? documents,
      signatureService: signatures,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> open(WidgetTester tester, DocumentReviewViewModel vm) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: DocumentReviewView(documentId: 'photo', viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Bind signature'));
    await tester.tap(find.text('Bind signature'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm and sign'));
    await tester.tap(find.text('Confirm and sign'));
  }

  for (final size in [const Size(360, 640), const Size(640, 320)]) {
    testWidgets('US-11 red disclaimer survives reopening at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => documents.upload(fixtures.jpegUpload('photo')),
      );
      await open(tester, createViewModel());
      expect(find.text(disclaimer), findsNothing);

      await tester.ensureVisible(find.text('Bind signature'));
      await tester.tap(find.text('Bind signature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(disclaimer), findsNothing);
      expect((await documents.getDocument('photo'))!.isSigned, isFalse);

      await confirm(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(disclaimer)).style!.color,
        Colors.red,
      );
      await tester.ensureVisible(find.text(disclaimer));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final signed =
          (await db.collection('uploadedDocuments').doc('photo').get()).data();

      // Dispose the screen and open a new one with fresh state from persistence.
      await tester.pumpWidget(const SizedBox.shrink());
      await signatures.save(drawing(.4));
      final reopened = createViewModel();
      await open(tester, reopened);
      expect(find.text(disclaimer), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(disclaimer)).style!.color,
        Colors.red,
      );
      expect(find.text('Bind signature'), findsNothing);
      expect(find.text('Remove document'), findsNothing);
      expect(reopened.canBind, isFalse);
      await reopened.bind();
      expect(await reopened.delete(), isFalse);
      expect(
        (await db.collection('uploadedDocuments').doc('photo').get()).data(),
        signed,
      );
      await tester.ensureVisible(find.text(disclaimer));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('US-11 pending and failed binding never show disclaimer', (
    tester,
  ) async {
    await tester.runAsync(() => documents.upload(fixtures.jpegUpload('photo')));
    final controlled = ControlledBindingService(db);
    final vm = createViewModel(controlled);
    await open(tester, vm);
    await confirm(tester);
    await tester.pump();
    expect(vm.isSaving, isTrue);
    expect(find.text(disclaimer), findsNothing);
    controlled.result.completeError(const DocumentException('Binding failed.'));
    await tester.pumpAndSettle();
    expect(find.text('Binding failed.'), findsOneWidget);
    expect(find.text(disclaimer), findsNothing);
    expect((await documents.getDocument('photo'))!.isSigned, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('US-11 unconfirmed commit shows disclaimer only after reload', (
    tester,
  ) async {
    await tester.runAsync(() => documents.upload(fixtures.jpegUpload('photo')));
    final controlled = ControlledBindingService(db);
    final vm = createViewModel(controlled);
    await open(tester, vm);
    await confirm(tester);
    await tester.pump();
    await documents.bindSignature('photo');
    controlled.result.completeError(
      const DocumentException('The binding could not be confirmed. Retry.'),
    );
    await tester.pumpAndSettle();
    expect(find.text(disclaimer), findsNothing);
    await vm.load('photo');
    await tester.pumpAndSettle();
    expect(find.text(disclaimer), findsOneWidget);
    expect(find.text('Bind signature'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
