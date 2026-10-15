import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:pdfrx/pdfrx.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/document_upload.dart';
import 'package:appartment_app_group_2/models/rental_application.dart';
import 'package:appartment_app_group_2/services/application_service.dart';
import 'package:appartment_app_group_2/services/document_service.dart';
import 'package:appartment_app_group_2/services/document_exception.dart';
import 'package:appartment_app_group_2/services/file_picker_service.dart';
import 'package:appartment_app_group_2/view_models/documents_view_model.dart';

const tenant = AppUser(
  id: 'tenant',
  email: 'tenant@example.test',
  emailVerified: true,
);
Uint8List jpegBytes() =>
    Uint8List.fromList(image.encodeJpg(image.Image(width: 12, height: 12)));
DocumentUpload jpegUpload(String id) => DocumentUpload(
  id: id,
  userId: tenant.id,
  name: '$id.jpg',
  bytes: jpegBytes(),
);
Uint8List pdfBytes() {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>',
    '<< /Length 0 >>\nstream\n\nendstream',
  ];
  var text = '%PDF-1.4\n';
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(text.length);
    text += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = text.length;
  text += 'xref\n0 5\n0000000000 65535 f \n';
  for (final offset in offsets.skip(1)) {
    text += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  text += 'trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return Uint8List.fromList(utf8.encode(text));
}

const apartment = Apartment(
  id: 'apt',
  title: 'Apartment',
  address: 'Test address',
  city: 'Zurich',
  listingType: ListingType.rent,
  price: 1500,
  rooms: 2,
  surface: 50,
  imageUrl: '',
  description: 'Test',
  availability: ApartmentAvailability.available,
);
ApplicationDetails applicationDetails() => ApplicationDetails(
  fullName: 'Tenant',
  phone: '123456789',
  moveInDate: DateTime.now().add(const Duration(days: 30)),
  occupants: 1,
);

class FixedPicker extends FilePickerService {
  FixedPicker(this.files);
  final List<DocumentUpload> files;
  @override
  Future<List<DocumentUpload>> pickDocuments(DocumentService service) async =>
      files;
}

class InterruptedUploadService extends DocumentService {
  InterruptedUploadService(FakeFirebaseFirestore db)
    : super(firestore: db, currentUser: () => tenant);
  bool failAfterSave = true;
  @override
  Future<void> upload(DocumentUpload upload) async {
    await super.upload(upload);
    if (failAfterSave) {
      failAfterSave = false;
      throw const DocumentException('Confirmation interrupted.');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    await pdfrxFlutterInitialize();
  });
  late FakeFirebaseFirestore db;
  late DocumentService service;
  setUp(() {
    db = FakeFirebaseFirestore();
    service = DocumentService(firestore: db, currentUser: () => tenant);
  });
  test('US-15 stores original JPEG bytes, metadata and owner; retries use the same ID', () async {
    final upload = jpegUpload('photo');
    await service.upload(upload);
    final first = (await db.collection('uploadedDocuments').doc('photo').get())
        .data();
    await service.upload(upload);
    expect((await db.collection('uploadedDocuments').get()).docs, hasLength(1));
    expect(
      (await db.collection('uploadedDocuments').doc('photo').get()).data(),
      first,
    );
    final file = (await service.getDocument('photo'))!;
    expect(file.bytes, upload.bytes);
    expect(file.userId, tenant.id);
    expect(file.canDelete, isTrue);
    expect(file.isSigned, isFalse);
  });
  test('US-15 accepts a readable PDF with original bytes preserved', () async {
    final bytes = pdfBytes();
    await service.upload(
      DocumentUpload(
        id: 'pdf',
        userId: tenant.id,
        name: 'lease.pdf',
        bytes: bytes,
      ),
    );
    final file = (await service.getDocument('pdf'))!;
    expect(file.isPdf, isTrue);
    expect(file.bytes, bytes);
  });
  test(
    'US-15 rejects empty, oversized, unsupported, mislabeled and corrupt files',
    () async {
      final files = [
        DocumentUpload(
          id: 'empty',
          userId: tenant.id,
          name: 'empty.jpg',
          bytes: Uint8List(0),
        ),
        DocumentUpload(
          id: 'big',
          userId: tenant.id,
          name: 'big.jpg',
          bytes: Uint8List(DocumentUpload.maxBytes + 1),
        ),
        DocumentUpload(
          id: 'png',
          userId: tenant.id,
          name: 'file.png',
          bytes: jpegBytes(),
        ),
        DocumentUpload(
          id: 'fake',
          userId: tenant.id,
          name: 'file.pdf',
          bytes: jpegBytes(),
        ),
        DocumentUpload(
          id: 'badjpg',
          userId: tenant.id,
          name: 'file.jpg',
          bytes: pdfBytes(),
        ),
        DocumentUpload(
          id: 'badpdf',
          userId: tenant.id,
          name: 'file.pdf',
          bytes: Uint8List.fromList(utf8.encode('%PDF-corrupt')),
        ),
      ];
      for (final file in files) {
        await expectLater(
          service.upload(file),
          throwsA(isA<DocumentException>()),
        );
      }
      expect((await db.collection('uploadedDocuments').get()).docs, isEmpty);
    },
  );
  test('US-15 enforces the exact 700 KiB byte boundary', () async {
    final bytes = Uint8List(DocumentUpload.maxBytes)..setAll(0, jpegBytes());
    await service.upload(
      DocumentUpload(
        id: 'boundary',
        userId: tenant.id,
        name: 'file.jpg',
        bytes: bytes,
      ),
    );
    expect(
      (await service.getDocument('boundary'))!.bytes.length,
      DocumentUpload.maxBytes,
    );
  });
  test(
    'US-15 denies changed identity and prevents overwriting an upload ID',
    () async {
      await service.upload(jpegUpload('photo'));
      await expectLater(
        service.upload(
          DocumentUpload(
            id: 'photo',
            userId: tenant.id,
            name: 'other.jpg',
            bytes: jpegBytes(),
          ),
        ),
        throwsA(isA<DocumentException>()),
      );
      final other = DocumentService(
        firestore: db,
        currentUser: () => const AppUser(
          id: 'other',
          email: 'other@example.test',
          emailVerified: true,
        ),
      );
      await expectLater(
        other.upload(jpegUpload('next')),
        throwsA(isA<DocumentException>()),
      );
      await expectLater(
        other.getDocument('photo'),
        throwsA(isA<DocumentException>()),
      );
      final unverified = DocumentService(
        firestore: db,
        currentUser: () =>
            const AppUser(id: 'tenant', email: '', emailVerified: false),
      );
      expect(
        () => unverified.watchMyDocuments(),
        throwsA(isA<DocumentException>()),
      );
    },
  );
  test(
    'US-15 queue keeps successful uploads and errors independently',
    () async {
      final bad = DocumentUpload(
        id: 'bad',
        userId: tenant.id,
        name: 'bad.jpg',
        bytes: Uint8List(0),
      );
      final vm = DocumentsViewModel(
        service: service,
        picker: FixedPicker([jpegUpload('one'), bad, jpegUpload('two')]),
      );
      addTearDown(vm.dispose);
      await vm.pickAndUpload();
      expect(vm.savedIds, {'one', 'two'});
      expect(vm.uploadErrors.keys, ['bad']);
      expect(
        (await db.collection('uploadedDocuments').get()).docs,
        hasLength(2),
      );
      vm.dismissUpload(bad);
      expect(vm.uploads.map((e) => e.id), isNot(contains('bad')));
    },
  );
  test('US-15 uncertain upload retry confirms one record', () async {
    final interrupted = InterruptedUploadService(db);
    final upload = jpegUpload('uncertain');
    final vm = DocumentsViewModel(
      service: interrupted,
      picker: FixedPicker([upload]),
    );
    addTearDown(vm.dispose);
    await vm.pickAndUpload();
    expect(vm.uploadErrors, contains('uncertain'));
    await vm.retryUpload(upload);
    expect(vm.savedIds, contains('uncertain'));
    expect((await db.collection('uploadedDocuments').get()).docs, hasLength(1));
  });
  test(
    'US-15 picker cancellation and selection limit do not write records',
    () async {
      final vm = DocumentsViewModel(service: service, picker: FixedPicker([]));
      await vm.pickAndUpload();
      expect(vm.actionError, isNull);
      vm.dispose();
      final tooMany = DocumentsViewModel(
        service: service,
        picker: FixedPicker(List.generate(11, (i) => jpegUpload('file-$i'))),
      );
      await tooMany.pickAndUpload();
      expect(tooMany.actionError, contains('10'));
      tooMany.dispose();
      expect((await db.collection('uploadedDocuments').get()).docs, isEmpty);
    },
  );
  test('US-15 application links are atomic, reusable, optional and backward compatible', () async {
    final applications = ApplicationService(
      firestore: db,
      currentUser: () => tenant,
    );
    await service.upload(jpegUpload('photo'));
    await applications.submit(
      apartment,
      applicationDetails(),
      documentIds: ['photo'],
      submissionId: 'app1',
    );
    expect((await service.getDocument('photo'))!.firstApplicationId, 'app1');
    await expectLater(
      service.delete('photo'),
      throwsA(isA<DocumentException>()),
    );
    await applications.submit(
      apartment,
      applicationDetails(),
      documentIds: ['photo'],
      submissionId: 'app2',
    );
    expect((await service.getDocument('photo'))!.firstApplicationId, 'app1');
    await applications.submit(
      apartment,
      applicationDetails(),
      submissionId: 'empty',
    );
    final legacy =
        (await db.collection('applications').doc('empty').get()).data()!
          ..remove('documentIds');
    expect(RentalApplication.fromMap('old', legacy).documentIds, isEmpty);
    expect((await applications.getApplication('app2'))!.documentIds, ['photo']);
  });
  test(
    'US-15 invalid attachment causes no application or partial linking',
    () async {
      final applications = ApplicationService(
        firestore: db,
        currentUser: () => tenant,
      );
      await service.upload(jpegUpload('photo'));
      await expectLater(
        applications.submit(
          apartment,
          applicationDetails(),
          documentIds: ['photo', 'missing'],
          submissionId: 'failed',
        ),
        throwsA(isA<DocumentException>()),
      );
      expect((await db.collection('applications').get()).docs, isEmpty);
      expect((await service.getDocument('photo'))!.firstApplicationId, isNull);
      await service.delete('photo');
      expect(await service.getDocument('photo'), isNull);
    },
  );
}
