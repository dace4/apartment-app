
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:pdfrx/pdfrx.dart';

import '../models/app_user.dart';
import '../models/document_upload.dart';
import '../models/uploaded_document.dart';
import 'document_exception.dart';

/// US-15: private, bounded file storage in Firestore (no Storage bucket).
class DocumentService {
  DocumentService({
    FirebaseFirestore? firestore,
    AppUser? Function()? currentUser,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore _db;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _files =>
      _db.collection('uploadedDocuments');
  static AppUser? _firebaseUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? null
        : AppUser(
            id: user.uid,
            email: user.email ?? '',
            emailVerified: user.emailVerified,
          );
  }

  String get userId {
    final user = _currentUser();
    if (user == null || !user.emailVerified) {
      throw const DocumentException(
        'Log in with a verified email to manage documents.',
      );
    }
    return user.id;
  }

  String newDocumentId() => _files.doc().id;
  UploadedDocument _decode(String id, Map<String, dynamic> map) =>
      UploadedDocument.fromMap(id, {
        ...map,
        'fileBytes': (map['fileBytes'] as Blob).bytes,
      });
  Stream<List<UploadedDocument>> watchMyDocuments() {
    final uid = userId;
    return _files
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .where((doc) => !doc.metadata.hasPendingWrites)
                  .map((doc) => _decode(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<UploadedDocument?> getDocument(String id) async {
    final uid = userId;
    final doc = await _files
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    final file = _decode(doc.id, doc.data()!);
    if (file.userId != uid) {
      throw const DocumentException('This document is unavailable.');
    }
    return file;
  }

  Future<List<UploadedDocument>> getMyDocuments() async {
    final uid = userId;
    final docs = await _files
        .where('userId', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    return docs.docs.map((doc) => _decode(doc.id, doc.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> validate(DocumentUpload upload) async {
    if (upload.selectionError != null) {
      throw DocumentException(upload.selectionError!);
    }
    if (upload.name.trim().isEmpty ||
        upload.name.length > 200 ||
        upload.name.contains('/') ||
        upload.name.contains('\\')) {
      throw const DocumentException(
        'Choose a file with a name of 1–200 characters.',
      );
    }
    if (upload.bytes.isEmpty || upload.bytes.length > DocumentUpload.maxBytes) {
      throw const DocumentException(
        'Choose a nonempty file no larger than 700 KiB.',
      );
    }
    if (upload.mimeType == 'image/jpeg') {
      if (!await compute(_readableJpeg, upload.bytes)) {
        throw const DocumentException(
          'This JPEG is corrupt, too large to preview, or is not a JPEG image.',
        );
      }
    } else if (upload.mimeType == 'application/pdf') {
      if (upload.bytes.length < 5 ||
          String.fromCharCodes(upload.bytes.take(5)) != '%PDF-') {
        throw const DocumentException('This file is not a readable PDF.');
      }
      PdfDocument? pdf;
      try {
        pdf = await PdfDocument.openData(
          upload.bytes,
          passwordProvider: () async => null,
        );
        if (pdf.isEncrypted || pdf.pages.isEmpty) throw const FormatException();
        final preview = await pdf.pages.first.render(width: 32, height: 32);
        if (preview == null) throw const FormatException();
        preview.dispose();
      } catch (_) {
        throw const DocumentException(
          'Choose a readable PDF without password protection.',
        );
      } finally {
        await pdf?.dispose();
      }
    } else {
      throw const DocumentException(
        'Only JPEG (.jpg/.jpeg) and PDF files are supported.',
      );
    }
  }

  Future<void> upload(DocumentUpload upload) async {
    final uid = userId;
    if (upload.userId != uid) {
      throw const DocumentException(
        'Your account changed. Select the file again.',
      );
    }
    await validate(upload);
    final ref = _files.doc(upload.id);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        final data = existing.data()!;
        if (data['userId'] != uid ||
            data['name'] != upload.name ||
            data['mimeType'] != upload.mimeType ||
            !listEquals((data['fileBytes'] as Blob).bytes, upload.bytes)) {
          throw const DocumentException(
            'This upload ID is already in use. Select the file again.',
          );
        }
        return;
      }
      tx.set(ref, {
        'userId': uid,
        'name': upload.name,
        'mimeType': upload.mimeType,
        'fileBytes': Blob(upload.bytes),
        'byteSize': upload.bytes.length,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'unsigned',
        'signatureId': null,
        'signedAt': null,
        'firstApplicationId': null,
      });
    }, timeout: const Duration(seconds: 20));
  }

  Future<void> delete(String id) async {
    final uid = userId;
    await _db.runTransaction((tx) async {
      final doc = await tx.get(_files.doc(id));
      if (!doc.exists) return;
      final file = _decode(doc.id, doc.data()!);
      if (file.userId != uid || !file.canDelete) {
        throw const DocumentException(
          'Signed documents and application attachments cannot be deleted.',
        );
      }
      tx.delete(doc.reference);
    });
  }
}

bool _readableJpeg(Uint8List bytes) {
  try {
    final decoder = image.JpegDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 20000000) {
      return false;
    }
    return decoder.decodeFrame(0) != null;
  } catch (_) {
    return false;
  }
}
