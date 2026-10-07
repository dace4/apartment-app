import 'package:cloud_firestore/cloud_firestore.dart';

/// US 12: the property and recipient information needed by the contact form.
/// Keeping this separate leaves the apartment browsing model independent.
class ContactListing {
  const ContactListing({
    required this.id,
    required this.title,
    required this.advertiserId,
    required this.advertiserName,
  });

  final String id;
  final String title;

  /// Firebase Auth UID used to authorize the advertiser's access to messages.
  final String advertiserId;
  final String advertiserName;
  bool get canContact =>
      advertiserId.trim().isNotEmpty && advertiserName.trim().isNotEmpty;
}

/// A frozen draft is reused after an uncertain response, preventing duplicates.
class MessageDraft {
  const MessageDraft({
    required this.id,
    required this.listing,
    required this.subject,
    required this.body,
  });
  final String id;
  final ContactListing listing;
  final String subject;
  final String body;
}

/// Combines the frozen draft with the signed-in sender's trusted identity.
class AdvertiserMessage {
  const AdvertiserMessage({
    required this.draft,
    required this.senderId,
    required this.senderEmail,
  });
  final MessageDraft draft;
  final String senderId;
  final String senderEmail;

  // Firestore generates createdAt, avoiding reliance on the device's clock.
  // The 'sent' state records storage, not that the advertiser has read it.
  Map<String, dynamic> toFirestore() => {
    'apartmentId': draft.listing.id,
    'advertiserId': draft.listing.advertiserId,
    'senderId': senderId,
    'senderEmail': senderEmail,
    'subject': draft.subject.trim(),
    'body': draft.body.trim(),
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'sent',
  };

  /// Allows an identical retry to confirm an existing message. Server-generated
  /// createdAt is excluded because it was not part of the original draft.
  bool matches(Map<String, dynamic> data) =>
      data['apartmentId'] == draft.listing.id &&
      data['advertiserId'] == draft.listing.advertiserId &&
      data['senderId'] == senderId &&
      data['senderEmail'] == senderEmail &&
      data['subject'] == draft.subject.trim() &&
      data['body'] == draft.body.trim() &&
      data['status'] == 'sent';
}

/// The stored message reference returned after submission is confirmed.
class MessageReceipt {
  const MessageReceipt(this.id);
  final String id;
}
