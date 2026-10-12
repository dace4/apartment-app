import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Thrown by [AuthService] with a message that can be shown to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Account creation, log in and log out with Firebase Authentication.
class AuthService {
  final _auth = FirebaseAuth.instance;

  /// The signed-in user, or null when nobody is logged in.
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  /// Emits on log in, log out and when the user changes (e.g. email verified).
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toAppUser);

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Creates the account, signs the user in and sends the verification email.
  Future<void> register(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Fetches the latest email verification state from Firebase.
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
    );
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'This email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'This password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
