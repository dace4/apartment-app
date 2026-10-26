import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../utils/validators.dart';

/// US-06: the name and phone of the Profile page, which pre-fill the forms
/// that ask for them (applications, insurance requests).
class ContactDetailsViewModel extends ChangeNotifier {
  // Tests pass a fake service; the app uses the real Firebase one.
  ContactDetailsViewModel({AuthService? service})
    : service = service ?? AuthService();

  final AuthService service;
  bool isSaving = false;
  String? actionError;

  Future<bool> save(String fullName, String phone) async {
    final invalid = Validators.fullName(fullName) ?? Validators.phone(phone);
    if (invalid != null) {
      actionError = invalid;
      notifyListeners();
      return false;
    }
    isSaving = true;
    actionError = null;
    notifyListeners();
    try {
      await service.saveContactDetails(fullName, phone);
      return true;
    } on AuthException catch (e) {
      actionError = e.message;
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
