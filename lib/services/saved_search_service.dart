import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_search.dart';
import '../models/app_notification.dart';
import '../models/apartment_filter.dart';

/// US 23: saved searches are stored in the Firestore collection
/// `savedSearches`, one document per search with the user's id. Their alerts
/// are US 18 notifications of type newListing.
class SavedSearchService {
  final _firestore = FirebaseFirestore.instance;
  final _searches = FirebaseFirestore.instance.collection('savedSearches');
  final _notifications = FirebaseFirestore.instance.collection('notifications');

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<SavedSearch>> watchMySearches() {
    return _searches
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedSearch.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> create({
    required String name,
    required ApartmentFilter filter,
    required List<String> seenApartmentIds,
  }) {
    return _searches.add({
      'userId': _userId,
      'name': name.trim(),
      'filter': filter.toMap(),
      'alertsEnabled': true,
      'seenApartmentIds': seenApartmentIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setAlertsEnabled(String searchId, bool enabled) {
    return _searches.doc(searchId).update({'alertsEnabled': enabled});
  }

  Future<void> delete(String searchId) {
    return _searches.doc(searchId).delete();
  }

  /// Marks the offers as seen and creates their alerts in one batch: either
  /// both are saved, or neither. A fixed id per user, search and offer means
  /// an alert can never exist twice.
  Future<void> recordNewOffers(
    SavedSearch search,
    List<String> apartmentIds,
    List<AppNotification> alerts,
  ) {
    final batch = _firestore.batch();
    batch.update(_searches.doc(search.id), {
      'seenApartmentIds': FieldValue.arrayUnion(apartmentIds),
    });
    for (final alert in alerts) {
      batch.set(_notifications.doc('${_userId}_${alert.id}'), {
        ...alert.toMap(),
        'userId': _userId,
      });
    }
    return batch.commit();
  }
}
