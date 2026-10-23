import 'package:cloud_firestore/cloud_firestore.dart';

/// US 12: who to contact about an apartment. Stored in the Firestore
/// collection `advertiserContacts`, one document per apartment id.
class AdvertiserContact {
  const AdvertiserContact({
    required this.apartmentId,
    required this.advertiserId,
    required this.advertiserName,
  });

  final String apartmentId;

  /// Firebase Auth id of the advertiser, who can then read the message.
  final String advertiserId;
  final String advertiserName;

  factory AdvertiserContact.fromMap(
    String apartmentId,
    Map<String, dynamic> map,
  ) {
    return AdvertiserContact(
      apartmentId: apartmentId,
      advertiserId: map['advertiserId'] as String,
      advertiserName: map['advertiserName'] as String,
    );
  }
}

/// US 12: a question sent to the advertiser of an apartment. It can be read
/// by its sender, the advertiser, and the apartment's owner or managers.
class AdvertiserMessage {
  const AdvertiserMessage({
    required this.apartmentId,
    required this.advertiserId,
    required this.subject,
    required this.body,
    this.id = '',
    this.senderEmail = '',
    this.createdAt,
  });

  final String apartmentId;
  final String advertiserId;
  final String subject;
  final String body;

  /// Set when the message is read back from Firestore.
  final String id;
  final String senderEmail;
  final DateTime? createdAt;

  factory AdvertiserMessage.fromMap(String id, Map<String, dynamic> map) {
    return AdvertiserMessage(
      id: id,
      apartmentId: map['apartmentId'] as String,
      advertiserId: map['advertiserId'] as String,
      subject: map['subject'] as String,
      body: map['body'] as String,
      senderEmail: map['senderEmail'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apartmentId': apartmentId,
      'advertiserId': advertiserId,
      'subject': subject.trim(),
      'body': body.trim(),
    };
  }
}
