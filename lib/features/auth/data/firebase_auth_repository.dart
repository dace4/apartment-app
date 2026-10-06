import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';

/// [AuthRepository] backed by Firebase Authentication (email and password).
class FirebaseAuthRepository extends AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance {
    // userChanges also fires on sign in, sign out and token refresh.
    _subscription = _auth.userChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _run(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  @override
  Future<void> register({required String email, required String password}) {
    return _run(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
    });
  }

  @override
  Future<void> sendEmailVerification() {
    return _run(() async => _auth.currentUser?.sendEmailVerification());
  }

  @override
  Future<void> reloadUser() async {
    await _run(() async => _auth.currentUser?.reload());
    // reload() does not always emit on userChanges, so notify explicitly.
    notifyListeners();
  }

  @override
  Future<void> signOut() => _run(_auth.signOut);

  /// Runs a Firebase call and turns its errors into an [AuthException].
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  static String _messageFor(String code) {
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
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this app.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
