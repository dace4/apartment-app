import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// US-15: an owner's original file and its small, separately editable metadata.
class UploadedDocument {
  UploadedDocument({
    required this.id,
    required this.userId,
    required this.name,
    required this.mimeType,
    required Uint8List bytes,
    required this.createdAt,
    this.signatureId,
    this.signedAt,
    this.firstApplicationId,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String id;
  final String userId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final DateTime createdAt;
  final String? signatureId;
  final DateTime? signedAt;
  final String? firstApplicationId;
  bool get isPdf => mimeType == 'application/pdf';
  bool get isSigned => signatureId != null;
  bool get canDelete => !isSigned && firstApplicationId == null;
  String get statusLabel => isSigned ? 'Signed' : 'Unsigned';
  String get sizeLabel => '${(bytes.length / 1024).ceil()} KiB';
  factory UploadedDocument.fromMap(String id, Map<String, dynamic> map) =>
      UploadedDocument(
        id: id,
        userId: map['userId'] as String,
        name: map['name'] as String,
        mimeType: map['mimeType'] as String,
        bytes: map['fileBytes'] as Uint8List,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        signatureId: map['signatureId'] as String?,
        signedAt: (map['signedAt'] as Timestamp?)?.toDate(),
        firstApplicationId: map['firstApplicationId'] as String?,
      );
}
