import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/models/uploaded_document.dart';
import 'package:appartment_app_group_2/view_models/documents_view_model.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';
import 'package:appartment_app_group_2/views/documents/documents_view.dart';
import 'package:appartment_app_group_2/views/documents/document_review_view.dart';

import 'us15_documents_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    await pdfrxFlutterInitialize();
  });
  testWidgets('US-15 library shows upload, empty and per-file results', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    final vm = DocumentsViewModel(
      service: service,
      picker: fixtures.FixedPicker([fixtures.jpegUpload('photo')]),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(home: DocumentsView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.text('No documents uploaded yet.'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Upload documents'));
      for (var i = 0; i < 500 && vm.isPicking; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(vm.isPicking, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.textContaining('Unsigned'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [360.0, 800.0]) {
    testWidgets('US-15 JPEG preview and removal confirmation at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final service = DocumentService(
        firestore: db,
        currentUser: () => fixtures.tenant,
      );
      await tester.runAsync(() => service.upload(fixtures.jpegUpload('photo')));
      final vm = DocumentReviewViewModel(service: service);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentReviewView(documentId: 'photo', viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('photo.jpg'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.text('Remove document'));
      await tester.pumpAndSettle();
      expect(find.text('Remove document?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await service.getDocument('photo'), isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('US-15 PDF preview uses the original bytes', (tester) async {
    final db = FakeFirebaseFirestore();
    final service = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    // A stored valid fixture tests the View independently of native validation.
    final file = fixtures.pdfBytes();
    final vm = _PdfReview(service, file);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentReviewView(documentId: 'pdf', viewModel: vm),
      ),
    );
    await tester.pump();
    expect(find.byType(PdfViewer), findsOneWidget);
    expect(
      tester.widget<PdfViewer>(find.byType(PdfViewer)).documentRef,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

// Use a memory fixture without a server or timing-dependent platform decoder.
class _PdfReview extends DocumentReviewViewModel {
  _PdfReview(DocumentService service, this.file) : super(service: service);
  final Uint8List file;
  @override
  Future<void> load(String id) async {
    document = UploadedDocument(
      id: id,
      userId: fixtures.tenant.id,
      name: 'lease.pdf',
      mimeType: 'application/pdf',
      bytes: file,
      createdAt: DateTime.utc(2026, 10, 15),
    );
    notifyListeners();
  }
}
