import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../models/user_role.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel({AuthService? service})
    : service = service ?? AuthService();
  final AuthService service;
  Set<UserRole> roles = {};

  void setRole(UserRole role, bool selected) {
    // Admin is granted in the Firebase console, never at registration.
    if (!UserRole.selectable.contains(role)) return;
    roles = {...roles};
    if (selected) {
      roles.add(role);
    } else {
      roles.remove(role);
    }
    notifyListeners();
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool isLoading = false;
  String? errorMessage;

  /// US-06: [fullName] and [phone] are saved in the profile and pre-fill
  /// the forms that ask for them.
  Future<void> register(
    String email,
    String password, {
    required String fullName,
    required String phone,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await service.register(
        email,
        password,
        roles,
        fullName: fullName,
        phone: phone,
      );
      // Success: the router opens the Verify email page.
    } on AuthException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? validateConfirmation(String password, String? confirmation) {
    if (confirmation != password) return 'Passwords do not match.';
    return null;
  }
}
