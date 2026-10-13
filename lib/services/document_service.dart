import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/signature_drawing.dart';
import '../models/signed_document.dart';
import '../models/signing_consent.dart';
import '../models/signing_document.dart';
import '../utils/document_integrity.dart';
import 'document_exception.dart';

/// US-11: all Firebase access for assigned documents and signed records.
class DocumentService {
  DocumentService({
    FirebaseFirestore? firestore,
    AppUser? Function()? currentUser,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? _firebaseUser;

  final FirebaseFirestore _firestore;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection('signingDocuments');
  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection('signedDocuments');

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

  AppUser _requireUser() {
    final user = _currentUser();
    if (user == null || !user.emailVerified || user.email.isEmpty) {
      throw const DocumentException(
        'Log in with a verified email to sign documents.',
      );
    }
    return user;
  }

  Stream<List<SigningDocument>> watchMyDocuments() {
    final user = _requireUser();
    return _documents
        .where('userId', isEqualTo: user.id)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SigningDocument.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt)),
        );
  }

  Stream<Set<String>> watchMySignedIds() {
    final user = _requireUser();
    return _records
        .where('signerId', isEqualTo: user.id)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  /// Server reads prevent offline cache from presenting a signing success.
  Future<SigningDocument?> getDocument(String id) async {
    final user = _requireUser();
    final snapshot = await _documents
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final document = SigningDocument.fromMap(id, snapshot.data()!);
    if (document.userId != user.id || !document.isValid) {
      throw const DocumentException(
        'This document is unavailable. Contact the sender.',
      );
    }
    return document;
  }

  Future<SignedDocument?> getSignedRecord(String id) async {
    final user = _requireUser();
    final snapshot = await _records
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    try {
      final record = SignedDocument.fromMap(id, snapshot.data()!);
      if (record.signerId != user.id ||
          !hasRecordIntegrity(record) ||
          record.signedAt == null ||
          snapshot.data()!['consented'] != true) {
        throw const FormatException('Invalid record.');
      }
      return record;
    } catch (_) {
      throw const DocumentException(
        'This signed record failed its integrity check. Contact the sender.',
      );
    }
  }

  Future<void> sign({
    required SigningDocument reviewedDocument,
    required SignatureDrawing signature,
    required String signerName,
    required bool consented,
  }) async {
    final user = _requireUser();
    if (!consented ||
        !signature.hasInk ||
        signerName.trim().isEmpty ||
        signerName.trim().length > 100 ||
        !reviewedDocument.isValid ||
        reviewedDocument.userId != user.id ||
        !reviewedDocument.isReady) {
      throw const DocumentException(
        'Review the document, enter your name, draw your signature, and give consent.',
      );
    }
    final recordRef = _records.doc(reviewedDocument.id);
    final hash = documentFingerprint(reviewedDocument);
    await _firestore.runTransaction((transaction) async {
      // Deterministic ID: an acknowledged or uncertain retry never overwrites.
      final existing = await transaction.get(recordRef);
      if (existing.exists) {
        final record = SignedDocument.fromMap(existing.id, existing.data()!);
        if (record.signerId != user.id || !hasRecordIntegrity(record)) {
          throw const DocumentException(
            'This signed record failed its integrity check. Contact the sender.',
          );
        }
        return;
      }
      final source = await transaction.get(_documents.doc(reviewedDocument.id));
      if (!source.exists) {
        throw const DocumentException('This document is no longer available.');
      }
      final current = SigningDocument.fromMap(source.id, source.data()!);
      if (current.userId != user.id ||
          !current.isReady ||
          documentFingerprint(current) != hash) {
        throw const DocumentException(
          'This document changed or was withdrawn. Reload and review it before signing.',
        );
      }
      final name = signerName.trim();
      final record = SignedDocument(
        id: current.id,
        document: current,
        signerId: user.id,
        signerEmail: user.email,
        signerName: name,
        signature: signature,
        documentHash: hash,
        recordHash: signedRecordFingerprint(
          documentHash: hash,
          signerId: user.id,
          signerEmail: user.email,
          signerName: name,
          signature: signature.encode(),
          consentVersion: SigningConsent.version,
          consentText: SigningConsent.text,
        ),
        consentVersion: SigningConsent.version,
        consentText: SigningConsent.text,
        signedAt: null,
      );
      transaction.set(recordRef, {
        ...record.toMap(),
        'signedAt': FieldValue.serverTimestamp(),
      });
    }, timeout: const Duration(seconds: 20));
  }
}
