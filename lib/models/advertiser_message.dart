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

/// US 12: a question sent to the advertiser of an apartment.
class AdvertiserMessage {
  const AdvertiserMessage({
    required this.apartmentId,
    required this.advertiserId,
    required this.subject,
    required this.body,
  });

  final String apartmentId;
  final String advertiserId;
  final String subject;
  final String body;

  Map<String, dynamic> toMap() {
    return {
      'apartmentId': apartmentId,
      'advertiserId': advertiserId,
      'subject': subject.trim(),
      'body': body.trim(),
    };
  }
}
