import 'package:flutter/foundation.dart';

import '../models/advertiser_message.dart';
import '../models/apartment.dart';
import '../services/apartment_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

/// US 12: send a question to the advertiser of an apartment.
class ContactAdvertiserViewModel extends ChangeNotifier {
  final ApartmentService apartmentService = ApartmentService();
  final MessageService messageService = MessageService();
  final AuthService authService = AuthService();

  /// null once loaded means the apartment does not exist.
  Apartment? apartment;

  /// null once loaded means nobody can be contacted for this apartment.
  AdvertiserContact? contact;
  bool isLoading = false;
  String? errorMessage;

  bool isSending = false;
  String? sendError;

  /// Set once the message is stored: the page then shows a confirmation.
  String? sentMessageId;

  String get senderEmail => authService.currentUser?.email ?? '';

  Future<void> fetchContact(String apartmentId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await apartmentService.getApartment(apartmentId);
      if (apartment != null) {
        contact = await messageService.getAdvertiserContact(apartmentId);
      }
    } catch (e) {
      errorMessage = 'Could not load the advertiser.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> send(String subject, String body) async {
    isSending = true;
    sendError = null;
    notifyListeners();

    try {
      sentMessageId = await messageService
          .send(
            AdvertiserMessage(
              apartmentId: contact!.apartmentId,
              advertiserId: contact!.advertiserId,
              subject: subject,
              body: body,
            ),
          )
          // Offline, Firestore waits forever for the server: stop waiting.
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      sendError =
          'Could not send the message. Check your connection and try '
          'again.';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}
