import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';
import 'auth_service.dart';

/// US-06: the only client-editable account fields are the selected roles,
/// the full name and the phone number.
class UserProfileService {
  UserProfileService({this._firestore});
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<UserProfile> watchProfile(String uid) =>
      _doc(uid).snapshots().map((doc) => UserProfile.fromMap(doc.data()));

  /// Registration: roles, name and phone in one write.
  Future<void> createProfile(String uid, UserProfile profile) async {
    if (profile.roles.isEmpty) {
      throw const AuthException('Choose at least one role.');
    }
    try {
      await _doc(uid).set(profile.toMap());
    } on FirebaseException {
      throw const AuthException(
        'Could not save your profile. Please try again.',
      );
    }
  }

  /// Merged, so the name and phone are kept.
  Future<void> saveRoles(String uid, Set<UserRole> roles) async {
    if (roles.isEmpty) throw const AuthException('Choose at least one role.');
    try {
      await _doc(uid).set({
        'roles': UserRole.values
            .where(roles.contains)
            .map((r) => r.name)
            .toList(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw const AuthException('Could not save your roles. Please try again.');
    }
  }

  /// Merged, so the roles are kept.
  Future<void> saveContactDetails(
    String uid,
    String fullName,
    String phone,
  ) async {
    try {
      await _doc(uid).set({
        'fullName': fullName.trim(),
        'phone': phone.trim(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      throw const AuthException(
        'Could not save your contact details. Please try again.',
      );
    }
  }
}
