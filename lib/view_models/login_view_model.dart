import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService service = AuthService();

  bool isLoading = false;
  String? errorMessage;

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await service.signIn(email, password);
      // Success: the router leaves this page, nothing else to update.
    } on AuthException catch (e) {
      errorMessage = e.message;
      isLoading = false;
      notifyListeners();
    }
  }
}
