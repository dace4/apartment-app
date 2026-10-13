import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/signature_drawing.dart';
import 'package:appartment_app_group_2/models/signature_point.dart';
import 'package:appartment_app_group_2/models/signed_document.dart';
import 'package:appartment_app_group_2/models/signing_consent.dart';
import 'package:appartment_app_group_2/models/signing_document.dart';
import 'package:appartment_app_group_2/services/document_exception.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/utils/document_integrity.dart';
import 'package:appartment_app_group_2/view_models/document_review_view_model.dart';
import 'package:appartment_app_group_2/view_models/documents_view_model.dart';

const user = AppUser(
  id: 'tenant',
  email: 'tenant@example.test',
  emailVerified: true,
);
final drawing = SignatureDrawing([
  [
    const SignaturePoint(.1, .2),
    const SignaturePoint(.5, .6),
    const SignaturePoint(.9, .3),
  ],
]);
SigningDocument assignment({
  String body = 'Please review these rental terms.',
  String state = 'ready',
  int version = 1,
}) => SigningDocument(
  id: 'lease-1',
  userId: user.id,
  title: 'Rental agreement',
  body: body,
  version: version,
  issuedAt: DateTime.utc(2026, 10, 13),
  state: state,
);

class FailingDocumentService extends DocumentService {
  FailingDocumentService(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, currentUser: () => user);
  bool failSign = true;
  @override
  Future<void> sign({
    required SigningDocument reviewedDocument,
    required SignatureDrawing signature,
    required String signerName,
    required bool consented,
  }) async {
    if (failSign) throw const DocumentException('Connection failed. Retry.');
    return super.sign(
      reviewedDocument: reviewedDocument,
      signature: signature,
      signerName: signerName,
      consented: consented,
    );
  }
}

class UncertainDocumentService extends DocumentService {
  UncertainDocumentService(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, currentUser: () => user);
  bool failConfirmation = true;
  @override
  Future<SignedDocument?> getSignedRecord(String id) async {
    final record = await super.getSignedRecord(id);
    if (record != null && failConfirmation) {
      failConfirmation = false;
      throw const DocumentException('Confirmation was interrupted. Retry.');
    }
    return record;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late DocumentService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = DocumentService(firestore: db, currentUser: () => user);
    await db
        .collection('signingDocuments')
        .doc('lease-1')
        .set(assignment().toMap());
  });

  Future<void> sign([SigningDocument? document]) => service.sign(
    reviewedDocument: document ?? assignment(),
    signature: drawing,
    signerName: ' Tenant Name ',
    consented: true,
  );

  group('US-11.1 and US-11.3 audit and binding', () {
    test(
      'saves original, identity, exact consent, signature and server time',
      () async {
        await sign();
        final record = (await service.getSignedRecord('lease-1'))!;
        expect(record.document.body, assignment().body);
        expect(record.signature.encode(), drawing.encode());
        expect(record.signerId, user.id);
        expect(record.signerEmail, user.email);
        expect(record.signerName, 'Tenant Name');
        expect(record.consentText, SigningConsent.text);
        expect(record.consentVersion, SigningConsent.version);
        expect(record.signedAt, isNotNull);
        expect(hasRecordIntegrity(record), isTrue);
        expect(
          (await db.collection('signingDocuments').doc('lease-1').get()).data(),
          assignment().toMap(),
        );
      },
    );
    test(
      'preserves Firestore timestamp nanoseconds in the copied snapshot',
      () async {
        final source = {
          ...assignment().toMap(),
          'issuedAt': Timestamp(1791849600, 123456789),
        };
        await db.collection('signingDocuments').doc('lease-1').set(source);
        final document = (await service.getDocument('lease-1'))!;
        expect(document.toMap()['issuedAt'], source['issuedAt']);
        await sign(document);
        expect(
          (await service.getSignedRecord('lease-1'))!.document
              .toMap()['issuedAt'],
          source['issuedAt'],
        );
      },
    );
    test(
      'repeat signing returns the original record without changing audit',
      () async {
        await sign();
        final original =
            (await db.collection('signedDocuments').doc('lease-1').get())
                .data();
        await service.sign(
          reviewedDocument: assignment(),
          signature: drawing,
          signerName: 'A different name',
          consented: true,
        );
        expect(
          (await db.collection('signedDocuments').get()).docs,
          hasLength(1),
        );
        expect(
          (await db.collection('signedDocuments').doc('lease-1').get()).data(),
          original,
        );
      },
    );
    test('no record exists before signing', () async {
      expect(await service.getSignedRecord('lease-1'), isNull);
    });
  });

  group('US-11.4 invalid and failed signatures', () {
    test('refuses missing consent and blank or dot signatures', () async {
      await expectLater(
        service.sign(
          reviewedDocument: assignment(),
          signature: drawing,
          signerName: 'Tenant',
          consented: false,
        ),
        throwsA(isA<DocumentException>()),
      );
      for (final invalid in [
        SignatureDrawing([]),
        SignatureDrawing([
          [const SignaturePoint(.1, .1)],
        ]),
        SignatureDrawing([
          [const SignaturePoint(double.nan, .1)],
        ]),
      ]) {
        await expectLater(
          service.sign(
            reviewedDocument: assignment(),
            signature: invalid,
            signerName: 'Tenant',
            consented: true,
          ),
          throwsA(isA<DocumentException>()),
        );
      }
      expect((await db.collection('signedDocuments').get()).docs, isEmpty);
    });
    test('refuses missing name', () async {
      await expectLater(
        service.sign(
          reviewedDocument: assignment(),
          signature: drawing,
          signerName: ' ',
          consented: true,
        ),
        throwsA(isA<DocumentException>()),
      );
    });
    test('refuses unverified and signed-out accounts', () async {
      for (final identity in [
        null,
        const AppUser(
          id: 'tenant',
          email: 'tenant@example.test',
          emailVerified: false,
        ),
      ]) {
        final restricted = DocumentService(
          firestore: db,
          currentUser: () => identity,
        );
        await expectLater(
          restricted.sign(
            reviewedDocument: assignment(),
            signature: drawing,
            signerName: 'Tenant',
            consented: true,
          ),
          throwsA(isA<DocumentException>()),
        );
      }
    });
    test('refuses changed content and changed version after review', () async {
      for (final changed in [
        assignment(body: 'Revised terms'),
        assignment(version: 2),
      ]) {
        await db
            .collection('signingDocuments')
            .doc('lease-1')
            .set(changed.toMap());
        await expectLater(sign(), throwsA(isA<DocumentException>()));
      }
      expect((await db.collection('signedDocuments').get()).docs, isEmpty);
    });
    test('refuses withdrawn, deleted and reassigned documents', () async {
      await db.collection('signingDocuments').doc('lease-1').update({
        'state': 'withdrawn',
      });
      await expectLater(sign(), throwsA(isA<DocumentException>()));
      await db.collection('signingDocuments').doc('lease-1').update({
        'state': 'ready',
        'userId': 'other',
      });
      await expectLater(sign(), throwsA(isA<DocumentException>()));
      await db.collection('signingDocuments').doc('lease-1').delete();
      await expectLater(sign(), throwsA(isA<DocumentException>()));
    });
    test(
      'detects tampering with content, identity, consent and signature',
      () async {
        await sign();
        final ref = db.collection('signedDocuments').doc('lease-1');
        final original = (await ref.get()).data()!;
        for (final changed in [
          {
            'document': {...assignment().toMap(), 'body': 'Changed'},
          },
          {'signerName': 'Other name'},
          {'consentText': 'Other consent'},
          {'consented': false},
          {'signature': '[]'},
          {
            'signature': SignatureDrawing([
              [const SignaturePoint(.2, .1), const SignaturePoint(.8, .7)],
            ]).encode(),
          },
        ]) {
          await ref.set({...original, ...changed});
          await expectLater(
            service.getSignedRecord('lease-1'),
            throwsA(isA<DocumentException>()),
          );
        }
      },
    );
  });

  group('US-11.2 and US-11.4 screen state', () {
    void fill(DocumentReviewViewModel vm) {
      vm.setReviewed(true);
      vm.setSignerName('Tenant Name');
      vm.startStroke(const SignaturePoint(.1, .2));
      vm.addPoint(const SignaturePoint(.9, .6));
      vm.setConsented(true);
    }

    test('requires review before consent; reload discards previous consent and strokes', () async {
      final vm = DocumentReviewViewModel(service: service);
      addTearDown(vm.dispose);
      await vm.load('lease-1');
      vm.setConsented(true);
      expect(vm.consented, isFalse);
      fill(vm);
      expect(vm.canSubmit, isTrue);
      vm.setReviewed(false);
      expect(vm.consented, isFalse);
      expect(vm.canSubmit, isFalse);
      fill(vm);
      await vm.load('lease-1');
      expect(vm.reviewed, isFalse);
      expect(vm.consented, isFalse);
      expect(vm.signature.pointCount, 0);
    });
    test(
      'failed save preserves input and retry confirms the stored record',
      () async {
        final failing = FailingDocumentService(db);
        final vm = DocumentReviewViewModel(service: failing);
        addTearDown(vm.dispose);
        await vm.load('lease-1');
        fill(vm);
        expect(await vm.sign(), isFalse);
        expect(vm.actionError, 'Connection failed. Retry.');
        expect(vm.signature.hasInk, isTrue);
        expect(vm.consented, isTrue);
        expect(vm.signedRecord, isNull);
        failing.failSign = false;
        expect(await vm.sign(), isTrue);
        expect(vm.signedRecord, isNotNull);
        expect(vm.canSubmit, isFalse);
        expect(await vm.sign(), isFalse);
      },
    );
    test('clear signature withdraws consent', () async {
      final vm = DocumentReviewViewModel(service: service);
      addTearDown(vm.dispose);
      await vm.load('lease-1');
      fill(vm);
      vm.clearSignature();
      expect(vm.signature.hasInk, isFalse);
      expect(vm.consented, isFalse);
      expect(vm.canSubmit, isFalse);
    });
    test(
      'uncertain save retries without duplicating or replacing the signature',
      () async {
        final vm = DocumentReviewViewModel(
          service: UncertainDocumentService(db),
        );
        addTearDown(vm.dispose);
        await vm.load('lease-1');
        fill(vm);
        expect(await vm.sign(), isFalse);
        expect(vm.signedRecord, isNull);
        final stored =
            (await db.collection('signedDocuments').doc('lease-1').get())
                .data();
        expect(stored, isNotNull);
        expect(await vm.sign(), isTrue);
        expect(
          (await db.collection('signedDocuments').doc('lease-1').get()).data(),
          stored,
        );
        expect(
          (await db.collection('signedDocuments').get()).docs,
          hasLength(1),
        );
      },
    );
    test('two immediate submissions result in one save', () async {
      final vm = DocumentReviewViewModel(service: service);
      addTearDown(vm.dispose);
      await vm.load('lease-1');
      fill(vm);
      final first = vm.sign();
      final second = vm.sign();
      expect(await second, isFalse);
      expect(await first, isTrue);
      expect((await db.collection('signedDocuments').get()).docs, hasLength(1));
    });
    test(
      'signed record reopens even if trusted staff remove its assignment',
      () async {
        await sign();
        await db.collection('signingDocuments').doc('lease-1').delete();
        final vm = DocumentReviewViewModel(service: service);
        addTearDown(vm.dispose);
        await vm.load('lease-1');
        expect(vm.signedRecord, isNotNull);
        expect(vm.document!.body, assignment().body);
        expect(vm.canSign, isFalse);
      },
    );
    test(
      'live list filters assignments and updates the signed status',
      () async {
        await db.collection('signingDocuments').doc('other').set({
          ...assignment().toMap(),
          'userId': 'other',
        });
        final vm = DocumentsViewModel(service: service);
        addTearDown(vm.dispose);
        vm.listenToDocuments();
        await Future<void>.delayed(Duration.zero);
        expect(vm.documents, hasLength(1));
        expect(vm.statusLabel(vm.documents.single), 'Awaiting signature');
        await sign();
        await Future<void>.delayed(Duration.zero);
        expect(vm.statusLabel(vm.documents.single), 'Signed');
      },
    );
  });
}
