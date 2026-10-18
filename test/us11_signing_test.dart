import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/signature_drawing.dart';
import 'package:appartment_app_group_2/models/signature_point.dart';
import 'package:appartment_app_group_2/models/user_signature.dart';
import 'package:appartment_app_group_2/models/uploaded_document.dart';
import 'package:appartment_app_group_2/services/signature_service.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/services/document_exception.dart';
import 'package:appartment_app_group_2/view_models/signature_view_model.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';

import 'us15_documents_test.dart' as fixtures;

SignatureDrawing drawing([double x = .7]) => SignatureDrawing([
  [
    const SignaturePoint(.1, .2),
    SignaturePoint(x, .6),
    const SignaturePoint(.8, .3),
  ],
]);

class FailedSignatureService extends SignatureService {
  FailedSignatureService(FakeFirebaseFirestore db)
    : super(firestore: db, currentUser: () => fixtures.tenant);
  @override
  Future<UserSignature> save(SignatureDrawing drawing) async =>
      throw const DocumentException('Connection failed. Retry.');
}

class UncertainBindingService extends DocumentService {
  UncertainBindingService(FakeFirebaseFirestore db)
    : super(firestore: db, currentUser: () => fixtures.tenant);
  bool fail = true;
  @override
  Future<UploadedDocument?> getDocument(String id) async {
    if (fail) {
      fail = false;
      throw const DocumentException('Confirmation failed. Retry.');
    }
    return super.getDocument(id);
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late SignatureService signatures;
  late DocumentService documents;
  setUp(() {
    db = FakeFirebaseFirestore();
    signatures = SignatureService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
    documents = DocumentService(
      firestore: db,
      currentUser: () => fixtures.tenant,
    );
  });
  test('US-11 save and replacement keep one stable signature ID', () async {
    expect(await signatures.getMySignature(), isNull);
    final original = await signatures.save(drawing());
    final replacement = await signatures.save(drawing(.4));
    expect(original.id, fixtures.tenant.id);
    expect(replacement.id, original.id);
    expect(replacement.drawing.encode(), isNot(original.drawing.encode()));
    expect((await db.collection('userSignatures').get()).docs, hasLength(1));
  });
  test('US-11 rejects blank and dot signatures', () async {
    for (final signature in [
      SignatureDrawing([]),
      SignatureDrawing([
        [const SignaturePoint(.1, .2)],
      ]),
    ]) {
      await expectLater(
        signatures.save(signature),
        throwsA(isA<DocumentException>()),
      );
    }
    expect((await db.collection('userSignatures').get()).docs, isEmpty);
  });
  test('US-11 binding requires an existing readable saved signature', () async {
    await documents.upload(fixtures.jpegUpload('file'));
    await expectLater(
      documents.bindSignature('file'),
      throwsA(isA<DocumentException>()),
    );
    await db.collection('userSignatures').doc(fixtures.tenant.id).set({
      'drawing': 'not a drawing',
      'updatedAt': Timestamp.now(),
    });
    expect(await signatures.getMySignature(), isNull);
    await expectLater(
      documents.bindSignature('file'),
      throwsA(isA<DocumentException>()),
    );
    expect((await documents.getDocument('file'))!.isSigned, isFalse);
  });
  test(
    'US-11 binding changes only state, signature ID and server time',
    () async {
      await documents.upload(fixtures.jpegUpload('file'));
      await signatures.save(drawing());
      final original =
          (await db.collection('uploadedDocuments').doc('file').get()).data()!;
      final bound = await documents.bindSignature('file');
      final signed =
          (await db.collection('uploadedDocuments').doc('file').get()).data()!;
      expect(bound.signatureId, fixtures.tenant.id);
      expect(bound.signedAt, isNotNull);
      for (final key in original.keys.where(
        (key) => !['status', 'signatureId', 'signedAt'].contains(key),
      )) {
        expect(signed[key], original[key], reason: key);
      }
      expect(signed.keys, original.keys);
      expect(bound.canDelete, isFalse);
      await expectLater(
        documents.delete('file'),
        throwsA(isA<DocumentException>()),
      );
    },
  );
  test('US-11 repeat binding and later signature replacement leave the signed record unchanged', () async {
    await documents.upload(fixtures.jpegUpload('file'));
    await signatures.save(drawing());
    await documents.bindSignature('file');
    final signed = (await db.collection('uploadedDocuments').doc('file').get())
        .data();
    await documents.bindSignature('file');
    await signatures.save(drawing(.4));
    expect(
      (await db.collection('uploadedDocuments').doc('file').get()).data(),
      signed,
    );
    expect((await documents.getDocument('file'))!.isSigned, isTrue);
  });
  test(
    'US-11 uncertain binding retry confirms the same signed state',
    () async {
      await documents.upload(fixtures.jpegUpload('file'));
      await signatures.save(drawing());
      final uncertain = UncertainBindingService(db);
      await expectLater(
        uncertain.bindSignature('file'),
        throwsA(isA<DocumentException>()),
      );
      final signed =
          (await db.collection('uploadedDocuments').doc('file').get()).data();
      expect((await uncertain.bindSignature('file')).isSigned, isTrue);
      expect(
        (await db.collection('uploadedDocuments').doc('file').get()).data(),
        signed,
      );
    },
  );
  test('US-11 failed signature save preserves a retryable draft', () async {
    final vm = SignatureViewModel(
      canAccess: () => true,
      service: FailedSignatureService(db),
    );
    addTearDown(vm.dispose);
    await vm.load();
    vm.startStroke(const SignaturePoint(.1, .1));
    vm.addPoint(const SignaturePoint(.8, .7));
    await vm.save();
    expect(vm.actionError, 'Connection failed. Retry.');
    expect(vm.drawing.hasInk, isTrue);
    expect(vm.canSave, isTrue);
    expect(vm.saved, isFalse);
  });
  test(
    'US-11 document screen disables binding until a signature exists',
    () async {
      await documents.upload(fixtures.jpegUpload('file'));
      final vm = DocumentReviewViewModel(
        canAccess: () => true,
        service: documents,
        signatureService: signatures,
      );
      addTearDown(vm.dispose);
      await vm.load('file');
      expect(vm.canBind, isFalse);
      await signatures.save(drawing());
      await vm.load('file');
      expect(vm.canBind, isTrue);
      await vm.bind();
      expect(vm.canBind, isFalse);
      expect(vm.document!.isSigned, isTrue);
    },
  );
}
