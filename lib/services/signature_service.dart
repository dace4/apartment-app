import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/signature_drawing.dart';
import '../models/user_signature.dart';
import 'document_exception.dart';

/// US-11: save and replace the current drawing without creating signature IDs.
class SignatureService {
  SignatureService({this.firestore, AppUser? Function()? currentUser})
    : _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore? firestore;
  final AppUser? Function() _currentUser;
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
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
        'Log in with a verified email to save a signature.',
      );
    }
    return user.id;
  }

  Future<UserSignature?> getMySignature() async {
    final id = userId;
    final doc = await _db
        .collection('userSignatures')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    try {
      return UserSignature.fromMap(id, doc.data()!);
    } catch (_) {
      return null;
    } // A malformed drawing must be replaced, not bound.
  }

  Future<UserSignature> save(SignatureDrawing drawing) async {
    final id = userId;
    if (!drawing.hasInk) {
      throw const DocumentException(
        'Draw a signature before saving. A dot is not enough.',
      );
    }
    final ref = _db.collection('userSignatures').doc(id);
    await _db.runTransaction((tx) async {
      await tx.get(ref);
      tx.set(ref, {
        'drawing': drawing.encode(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }, timeout: const Duration(seconds: 20));
    final saved = await getMySignature();
    if (saved == null) {
      throw const DocumentException('The save could not be confirmed. Retry.');
    }
    return saved;
  }
}
