import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/advertiser_message.dart';

/// US 12: messages to advertisers. firestore.rules check that the sender is
/// the signed-in user and that the advertiser matches the apartment.
class MessageService {
  MessageService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _contacts =>
      _db.collection('advertiserContacts');
  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('advertiserMessages');

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

  /// US 12 inbox: the messages about the owner's or manager's apartments,
  /// newest first. Queried 5 apartments at a time, so firestore.rules can
  /// check that the user manages each apartment.
  Future<List<AdvertiserMessage>> getMessagesForApartments(
    List<String> apartmentIds,
  ) async {
    final messages = <AdvertiserMessage>[];
    for (var i = 0; i < apartmentIds.length; i += 5) {
      final snapshot = await _messages
          .where('apartmentId', whereIn: apartmentIds.skip(i).take(5).toList())
          .get();
      messages.addAll(
        snapshot.docs.map(
          (doc) => AdvertiserMessage.fromMap(doc.id, doc.data()),
        ),
      );
    }
    final oldest = DateTime(0);
    return messages..sort(
      (a, b) => (b.createdAt ?? oldest).compareTo(a.createdAt ?? oldest),
    );
  }

  /// Returns null when the message does not exist.
  Future<AdvertiserMessage?> getMessage(String id) async {
    final doc = await _messages.doc(id).get();
    if (!doc.exists) return null;
    return AdvertiserMessage.fromMap(doc.id, doc.data()!);
  }
}
