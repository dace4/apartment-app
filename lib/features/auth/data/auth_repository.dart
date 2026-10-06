import 'package:flutter/foundation.dart';

/// The signed-in user, independent of Firebase so pages and tests
/// don't depend on the Firebase SDK.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final bool emailVerified;
}

/// Thrown by [AuthRepository] with a message that can be shown to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Account creation, log in and log out.
///
/// Notifies its listeners whenever the signed-in user changes, so the
/// router and the pages can react to it.
abstract class AuthRepository extends ChangeNotifier {
  /// The signed-in user, or null when nobody is logged in.
  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Creates the account, signs the user in and sends the
  /// verification email (US-06 acceptance criterion).
  Future<void> register({required String email, required String password});

  Future<void> sendEmailVerification();

  /// Fetches the latest email verification state from the server.
  Future<void> reloadUser();

  Future<void> signOut();
}
