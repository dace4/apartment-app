import 'package:flutter/foundation.dart';

import '../models/insurance_coverage.dart';
import '../models/insurance_request.dart';
import '../services/insurance_exception.dart';
import '../services/insurance_service.dart';
import '../utils/validators.dart';

/// US-19: one coverage's details, and the request to its agent.
class InsuranceContactViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // Tests pass a fake service and a short timeout.
  InsuranceContactViewModel({
    InsuranceService? service,
    this.sendTimeout = const Duration(seconds: 15),
  }) : service = service ?? InsuranceService();

  final InsuranceService service;

  /// Offline, Firestore waits forever for the server: stop waiting.
  final Duration sendTimeout;

  /// null once loaded means the coverage does not exist.
  InsuranceCoverage? coverage;
  bool isLoading = false;
  String? errorMessage;

  ContactMethod contactMethod = ContactMethod.email;

  bool isSending = false;
  String? actionError;

  /// Set once the request is stored: the page then shows a confirmation
  /// with this reference.
  String? sentRequestId;

  Future<void> fetchCoverage(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      coverage = await service.getCoverage(id);
    } catch (e) {
      errorMessage = 'Could not load this coverage.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectContactMethod(ContactMethod value) {
    contactMethod = value;
    notifyListeners();
  }

  /// The phone number is only needed when the renter wants to be called.
  String? validatePhone(String? value) =>
      contactMethod == ContactMethod.phone ? Validators.phone(value) : null;

  String? validateMessage(String? value) => Validators.messageBody(value);

  /// Returns true when the request was stored; [sentRequestId] is then set.
  Future<bool> send({required String phone, required String message}) async {
    if (validatePhone(phone) != null || validateMessage(message) != null) {
      actionError = 'Check the highlighted fields.';
      notifyListeners();
      return false;
    }
    isSending = true;
    actionError = null;
    notifyListeners();

    try {
      sentRequestId = await service
          .sendRequest(
            coverage: coverage!,
            contactMethod: contactMethod,
            phone: phone,
            message: message,
          )
          .timeout(sendTimeout);
      return true;
    } on InsuranceException catch (e) {
      actionError = e.message;
      return false;
    } catch (e) {
      actionError =
          'Your request was not delivered. Check your connection and try '
          'again.';
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
