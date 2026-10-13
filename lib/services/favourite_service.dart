import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase references to the current user's favourite apartments.
class FavouriteService {
  final _collection = FirebaseFirestore.instance.collection('favourites');

  String get _userId => FirebaseAuth.instance.currentUser!.uid;
  String _documentId(String apartmentId) => '${_userId}_$apartmentId';

  Stream<Set<String>> watchFavouriteIds() => _collection
      .where('userId', isEqualTo: _userId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => doc.data()['apartmentId'] as String)
            .toSet(),
      );

  Future<Set<String>> getFavouriteIds() async {
    final snapshot = await _collection.where('userId', isEqualTo: _userId).get();
    return snapshot.docs
        .map((doc) => doc.data()['apartmentId'] as String)
        .toSet();
  }

  Future<void> add(String apartmentId) => _collection.doc(_documentId(apartmentId)).set({
        'apartmentId': apartmentId,
        'userId': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String apartmentId) =>
      _collection.doc(_documentId(apartmentId)).delete();
}
