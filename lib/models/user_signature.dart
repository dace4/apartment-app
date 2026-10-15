import 'package:cloud_firestore/cloud_firestore.dart';

import 'signature_drawing.dart';

/// US-11: exactly one replaceable drawing, with the account UID as its stable ID.
class UserSignature {
  const UserSignature({
    required this.id,
    required this.drawing,
    required this.updatedAt,
  });
  final String id;
  final SignatureDrawing drawing;
  final DateTime updatedAt;
  factory UserSignature.fromMap(String id, Map<String, dynamic> map) =>
      UserSignature(
        id: id,
        drawing: SignatureDrawing.decode(map['drawing'] as String),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );
}
