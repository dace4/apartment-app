import 'package:flutter/foundation.dart';

import '../models/advertiser_message.dart';
import '../models/apartment.dart';
import '../services/apartment_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

/// US 12: send a question to the advertiser of an apartment.
class ContactAdvertiserViewModel extends ChangeNotifier {
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ContactAdvertiserViewModel({this._canAccess});
  final bool Function()? _canAccess;
  bool get hasAccess => !_disposed && _canAccess?.call() == true;
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
  String? actionError;

  /// Set once the message is stored: the page then shows a confirmation.
  String? sentMessageId;

  String get senderEmail => authService.currentUser?.email ?? '';

  Future<void> fetchContact(String apartmentId) async {
    if (!hasAccess) {
      errorMessage = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      apartment = await apartmentService.getApartment(apartmentId);
      if (apartment != null) {
        contact = await messageService.getAdvertiserContact(apartmentId);
        // Listings published in the app (US-24) have no advertiser contact:
        // the message goes to their owner.
        final ownerId = apartment!.ownerId;
        if (contact == null && ownerId != null) {
          contact = AdvertiserContact(
            apartmentId: apartmentId,
            advertiserId: ownerId,
            advertiserName: 'the owner',
          );
        }
      }
    } catch (e) {
      errorMessage = 'Could not load the advertiser.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> send(String subject, String body) async {
    if (!hasAccess) {
      actionError = 'Choose Buyer or Renter to use this feature.';
      notifyListeners();
      return;
    }
    isSending = true;
    actionError = null;
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
      actionError =
          'Could not send the message. Check your connection and try '
          'again.';
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
