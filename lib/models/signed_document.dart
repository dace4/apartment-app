import 'package:cloud_firestore/cloud_firestore.dart';

import 'signature_drawing.dart';
import 'signing_document.dart';

/// US-11: one immutable record per assigned document, including consent audit.
class SignedDocument {
  const SignedDocument({
    required this.id,
    required this.document,
    required this.signerId,
    required this.signerEmail,
    required this.signerName,
    required this.signature,
    required this.documentHash,
    required this.recordHash,
    required this.consentVersion,
    required this.consentText,
    required this.signedAt,
  });

  final String id;
  final SigningDocument document;
  final String signerId;
  final String signerEmail;
  final String signerName;
  final SignatureDrawing signature;
  final String documentHash;
  final String recordHash;
  final String consentVersion;
  final String consentText;
  final DateTime? signedAt;

  factory SignedDocument.fromMap(String id, Map<String, dynamic> map) =>
      SignedDocument(
        id: id,
        document: SigningDocument.fromMap(
          id,
          Map<String, dynamic>.from(map['document'] as Map),
        ),
        signerId: map['signerId'] as String,
        signerEmail: map['signerEmail'] as String,
        signerName: map['signerName'] as String,
        signature: SignatureDrawing.decode(map['signature'] as String),
        documentHash: map['documentHash'] as String,
        recordHash: map['recordHash'] as String,
        consentVersion: map['consentVersion'] as String,
        consentText: map['consentText'] as String,
        signedAt: (map['signedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
    'document': document.toMap(),
    'signerId': signerId,
    'signerEmail': signerEmail,
    'signerName': signerName,
    'signature': signature.encode(),
    'documentHash': documentHash,
    'recordHash': recordHash,
    'consentVersion': consentVersion,
    'consentText': consentText,
    'consented': true,
    'signedAt': signedAt == null ? null : Timestamp.fromDate(signedAt!),
  };
}
