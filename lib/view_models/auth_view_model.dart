import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// The signed-in user, shared by the whole app (see ARCHITECTURE.md §4).
/// The router listens to it to redirect on log in, log out and email
/// verification. Also used by the Verify email and Profile pages.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel() {
    _subscription = service.userChanges().listen((_) => notifyListeners());
  }

  final AuthService service = AuthService();
  late final StreamSubscription<AppUser?> _subscription;

  bool isLoading = false;

  /// Feedback shown on the Verify email page (sent again, not verified yet…).
  String? message;

  AppUser? get user => service.currentUser;

  Future<void> resendVerificationEmail() async {
    isLoading = true;
    message = null;
    notifyListeners();

    try {
      await service.sendEmailVerification();
      message = 'Confirmation email sent again.';
    } on AuthException catch (e) {
      message = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// When the email is verified, the router leaves the Verify email page.
  Future<void> checkEmailVerified() async {
    isLoading = true;
    message = null;
    notifyListeners();

    try {
      await service.reloadUser();
      if (user?.emailVerified != true) {
        message =
            'Your email is not verified yet. Open the link in the email first.';
      }
    } on AuthException catch (e) {
      message = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The router then goes back to the login page.
  Future<void> signOut() async {
    message = null;
    await service.signOut();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
