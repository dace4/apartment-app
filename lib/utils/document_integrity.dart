import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/signed_document.dart';
import '../models/signing_document.dart';

/// US-11: fixed-order, versioned JSON; no trimming or newline normalization.
String documentFingerprint(SigningDocument document) => _digest([
  'US-11-document-v1',
  document.id,
  document.userId,
  document.title,
  document.body,
  document.version,
  document.issuedAtSeconds,
  document.issuedAtNanoseconds,
  document.state,
]);

String signedRecordFingerprint({
  required String documentHash,
  required String signerId,
  required String signerEmail,
  required String signerName,
  required String signature,
  required String consentVersion,
  required String consentText,
}) => _digest([
  'US-11-record-v1',
  documentHash,
  signerId,
  signerEmail,
  signerName,
  signature,
  consentVersion,
  consentText,
]);

bool hasRecordIntegrity(SignedDocument record) =>
    record.document.isValid &&
    record.document.id == record.id &&
    record.document.userId == record.signerId &&
    record.signature.hasInk &&
    documentFingerprint(record.document) == record.documentHash &&
    signedRecordFingerprint(
          documentHash: record.documentHash,
          signerId: record.signerId,
          signerEmail: record.signerEmail,
          signerName: record.signerName,
          signature: record.signature.encode(),
          consentVersion: record.consentVersion,
          consentText: record.consentText,
        ) ==
        record.recordHash;

String _digest(List<Object> values) =>
    sha256.convert(utf8.encode(jsonEncode(values))).toString();
