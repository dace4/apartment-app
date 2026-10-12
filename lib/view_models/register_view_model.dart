import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthService service = AuthService();

  bool isLoading = false;
  String? errorMessage;

  Future<void> register(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await service.register(email, password);
      // Success: the router opens the Verify email page.
    } on AuthException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
    }
  }

  String? validateConfirmation(String password, String? confirmation) {
    if (confirmation != password) return 'Passwords do not match.';
    return null;
  }
}
