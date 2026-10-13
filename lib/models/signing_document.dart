import 'package:cloud_firestore/cloud_firestore.dart';

/// US-11: trusted staff assign an immutable text document to one signer.
class SigningDocument {
  SigningDocument({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.version,
    required this.issuedAt,
    int? issuedAtNanoseconds,
    this.state = 'ready',
  }) : issuedAtNanoseconds =
           issuedAtNanoseconds ??
           (issuedAt.microsecondsSinceEpoch % 1000000) * 1000;

  final String id;
  final String userId;
  final String title;
  final String body;
  final int version;
  final DateTime issuedAt;
  // Preserve Firestore nanoseconds when copying the authoritative snapshot.
  final int issuedAtNanoseconds;
  int get issuedAtSeconds => issuedAt.microsecondsSinceEpoch ~/ 1000000;
  final String state;

  bool get isReady => state == 'ready';

  bool get isValid =>
      id.isNotEmpty &&
      userId.isNotEmpty &&
      title.trim().isNotEmpty &&
      title.length <= 200 &&
      body.trim().isNotEmpty &&
      body.length <= 100000 &&
      version > 0 &&
      (state == 'ready' || state == 'withdrawn');

  factory SigningDocument.fromMap(String id, Map<String, dynamic> map) =>
      SigningDocument(
        id: id,
        userId: map['userId'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        version: map['version'] as int,
        issuedAt: (map['issuedAt'] as Timestamp).toDate(),
        issuedAtNanoseconds: (map['issuedAt'] as Timestamp).nanoseconds,
        state: map['state'] as String,
      );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'body': body,
    'version': version,
    'issuedAt': Timestamp(issuedAtSeconds, issuedAtNanoseconds),
    'state': state,
  };
}
