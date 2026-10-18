import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_role.dart';
import 'auth_service.dart';

/// US-06: the only client-editable account fields are the selected roles.
class UserProfileService {
  UserProfileService({this._firestore});
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<Set<UserRole>> watchRoles(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => UserRole.fromNames(doc.data()?['roles']));

  Future<void> saveRoles(String uid, Set<UserRole> roles) async {
    if (roles.isEmpty) throw const AuthException('Choose at least one role.');
    try {
      await _db.collection('users').doc(uid).set({
        'roles': UserRole.values
            .where(roles.contains)
            .map((r) => r.name)
            .toList(),
      });
    } on FirebaseException {
      throw const AuthException('Could not save your roles. Please try again.');
    }
  }
}
