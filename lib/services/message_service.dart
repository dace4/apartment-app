import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/advertiser_message.dart';

/// US 12: messages to advertisers. firestore.rules check that the sender is
/// the signed-in user and that the advertiser matches the apartment.
class MessageService {
  final _contacts = FirebaseFirestore.instance.collection('advertiserContacts');
  final _messages = FirebaseFirestore.instance.collection('advertiserMessages');

  /// Returns null when no advertiser is registered for this apartment.
  Future<AdvertiserContact?> getAdvertiserContact(String apartmentId) async {
    final doc = await _contacts.doc(apartmentId).get();
    if (!doc.exists) return null;
    return AdvertiserContact.fromMap(doc.id, doc.data()!);
  }

  /// Returns the id of the stored message.
  Future<String> send(AdvertiserMessage message) async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await _messages.add({
      ...message.toMap(),
      'senderId': user.uid,
      'senderEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
    return doc.id;
  }
}
