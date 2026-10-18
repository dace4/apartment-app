import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import 'user_profile_service.dart';

/// Thrown by [AuthService] with a message that can be shown to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Account creation, log in and log out with Firebase Authentication.
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final profiles = UserProfileService();

  /// The signed-in user, or null when nobody is logged in.
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  /// Emits on log in, log out and when the user changes (e.g. email verified).
  Stream<AppUser?> userChanges() => Stream.multi((controller) {
    StreamSubscription<Set<UserRole>>? profileSubscription;
    var generation = 0;
    final authSubscription = _auth.userChanges().listen((firebaseUser) async {
      final current = ++generation;
      await profileSubscription?.cancel();
      if (current != generation) return;
      if (firebaseUser == null) {
        controller.add(null);
        return;
      }
      AppUser account({
        Set<UserRole> roles = const {},
        bool loaded = false,
        String? error,
      }) => AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        emailVerified: firebaseUser.emailVerified,
        roles: roles,
        rolesLoaded: loaded,
        profileError: error,
      );
      controller.add(account());
      profileSubscription = profiles
          .watchRoles(firebaseUser.uid)
          .listen(
            (roles) {
              if (current == generation) {
                controller.add(account(roles: roles, loaded: true));
              }
            },
            onError: (Object error) {
              if (current == generation) {
                controller.add(
                  account(
                    loaded: true,
                    error: 'Could not load your roles. Please retry.',
                  ),
                );
              }
            },
          );
    }, onError: controller.addError);
    controller.onCancel = () {
      generation++;
      authSubscription.cancel();
      profileSubscription?.cancel();
    };
  });

  Future<AppUser?> loadUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final roles = await profiles.watchRoles(user.uid).first;
    // Do not return a previous account after an asynchronous profile read.
    if (_auth.currentUser?.uid != user.uid) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
      roles: roles,
    );
  }

  Future<void> saveRoles(Set<UserRole> roles) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Log in to choose your roles.');
    await profiles.saveRoles(user.uid, roles);
  }

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
  Future<void> register(
    String email,
    String password,
    Set<UserRole> roles,
  ) async {
    if (roles.isEmpty) throw const AuthException('Choose at least one role.');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
      // If this write fails, Auth already exists. The verified account completes
      // its profile on the role-selection screen rather than registering again.
      await saveRoles(roles);
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
      // firestore.rules read "email verified" from the login token: get a
      // new token so they see the verification right away.
      if (_auth.currentUser?.emailVerified == true) {
        await _auth.currentUser!.getIdToken(true);
      }
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
