import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/auth_repository.dart';
import '../models/advertiser_message.dart';
import '../utils/message_validators.dart';
import 'message_repository.dart';

/// US 12: submits messages through Firestore using the existing auth repository.
class FirebaseMessageRepository extends MessageRepository {
  FirebaseMessageRepository({
    required this.firestore,
    required this.authRepository,
    this.refreshSession,
  });
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final Future<void> Function()? refreshSession;

  @override
  // Creating a document reference allocates an ID without writing a document.
  String createMessageId() =>
      firestore.collection('advertiserMessages').doc().id;

  @override
  Future<MessageReceipt> send(MessageDraft draft) async {
    // Recheck identity and validation at the service boundary. A caller can
    // bypass the form, and the Firestore rules enforce these checks independently.
    final user = authRepository.currentUser;
    if (user == null || !user.emailVerified) {
      throw const MessageException(
        'Log in with a verified email to send a message.',
      );
    }
    final validation =
        MessageValidators.subject(draft.subject) ??
        MessageValidators.body(draft.body);
    if (validation != null) throw MessageException(validation);
    if (!draft.listing.canContact) {
      throw const MessageException(
        'No advertiser contact is available for this apartment.',
      );
    }
    // The form cannot choose the sender UID or email; both come from the account.
    final message = AdvertiserMessage(
      draft: draft,
      senderId: user.id,
      senderEmail: user.email,
    );
    final reference = firestore.collection('advertiserMessages').doc(draft.id);
    try {
      await refreshSession?.call();
      // An account change while refreshing must not send the previous user's
      // enquiry from a new session.
      if (authRepository.currentUser?.id != user.id ||
          authRepository.currentUser?.emailVerified != true) {
        throw const MessageException(
          'Log in again before sending this message.',
        );
      }
      // A transaction requires a server connection. It does not report a queued
      // offline write as sent. Reusing the ID safely confirms a previous send.
      await firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        // A previous attempt may have succeeded even if its response was lost.
        // Confirm that exact payload instead of overwriting or duplicating it.
        if (existing.exists) {
          if (!message.matches(existing.data()!)) {
            throw const MessageException(
              'This message reference belongs to a different submission.',
            );
          }
          return;
        }
        // Read only US 12's recipient mapping. Apartment browsing stays local.
        // Firestore retries if the advertiser changes during this transaction.
        final listing = await transaction.get(
          firestore.collection('advertiserContacts').doc(draft.listing.id),
        );
        if (!listing.exists) {
          throw const MessageException(
            'No advertiser contact is available for this apartment.',
          );
        }
        if (listing.data()!['advertiserId'] != draft.listing.advertiserId) {
          throw const MessageException(
            'The advertiser changed. Reload this apartment before sending.',
          );
        }
        transaction.set(reference, message.toFirestore());
      });
      // Only a successful transaction reaches the confirmation shown in the UI.
      return MessageReceipt(reference.id);
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw const MessageException(
            'You do not have permission to send this message. Please contact support.',
          );
        case 'unauthenticated':
          throw const MessageException(
            'Your session cannot send this message. Log in again and retry.',
          );
        case 'unavailable':
        // Network/transaction failures leave the result uncertain. The page
        // retains the draft and ID so the next attempt can confirm it safely.
        case 'network-request-failed':
        case 'deadline-exceeded':
        case 'aborted':
          throw const MessageException(
            'Could not confirm delivery. Check your connection and try again.',
            confirmationPending: true,
          );
        default:
          throw const MessageException(
            'Could not confirm delivery. Please try again.',
            confirmationPending: true,
          );
      }
    }
  }
}
