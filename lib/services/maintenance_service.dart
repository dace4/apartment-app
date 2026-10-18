import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import 'auth_service.dart';
import '../models/maintenance_request.dart';

/// US-17: maintenance requests are stored in the Firestore collection
/// `maintenanceRequests`. firestore.rules only lets users read and change
/// their own requests, and only before the service starts.
class MaintenanceService {
  final _collection = FirebaseFirestore.instance.collection(
    'maintenanceRequests',
  );

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  /// US-07: assignment queries also define the permitted maintenance queries.
  /// Listen to both role and property changes so revoked assignments clear data.
  Stream<List<Apartment>> watchManageableApartments() => Stream.multi((output) {
    final propertySubscriptions = <StreamSubscription>[];
    var generation = 0;
    final authSubscription = AuthService().userChanges().listen((user) async {
      final current = ++generation;
      for (final subscription in propertySubscriptions) {
        await subscription.cancel();
      }
      propertySubscriptions.clear();
      if (current != generation) return;
      output.add([]);
      if (user == null || !user.isReady || !user.hasManagementRole) return;
      final collection = FirebaseFirestore.instance.collection('apartments');
      final queries = [
        if (user.isHomeowner) collection.where('ownerId', isEqualTo: user.id),
        if (user.isPropertyManager)
          collection.where('managerIds', arrayContains: user.id),
      ];
      final parts = <int, List<Apartment>>{};
      for (var index = 0; index < queries.length; index++) {
        final key = index;
        propertySubscriptions.add(
          queries[index].snapshots().listen((snapshot) {
            if (current != generation) return;
            parts[key] = snapshot.docs
                .map((doc) => Apartment.fromMap(doc.id, doc.data()))
                .toList();
            if (parts.length == queries.length) {
              output.add(
                {
                  for (final part in parts.values)
                    for (final apartment in part) apartment.id: apartment,
                }.values.toList(),
              );
            }
          }, onError: output.addError),
        );
      }
    }, onError: output.addError);
    output.onCancel = () {
      generation++;
      authSubscription.cancel();
      for (final subscription in propertySubscriptions) {
        subscription.cancel();
      }
    };
  });

  Future<List<Apartment>> getManageableApartments() async {
    final user = await AuthService().loadUser();
    if (user == null || !user.isReady || !user.hasManagementRole) return [];
    final collection = FirebaseFirestore.instance.collection('apartments');
    final snapshots = await Future.wait([
      if (user.isHomeowner)
        collection.where('ownerId', isEqualTo: user.id).get(),
      if (user.isPropertyManager)
        collection.where('managerIds', arrayContains: user.id).get(),
    ]);
    return {
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs)
          doc.id: Apartment.fromMap(doc.id, doc.data()),
    }.values.toList();
  }

  Stream<List<MaintenanceRequest>> watchMyRequests() => Stream.multi((output) {
    final requestSubscriptions = <StreamSubscription>[];
    var generation = 0;
    final properties = watchManageableApartments().listen((apartments) async {
      final current = ++generation;
      for (final subscription in requestSubscriptions) {
        await subscription.cancel();
      }
      requestSubscriptions.clear();
      if (current != generation) return;
      output.add([]);
      final parts = <int, List<MaintenanceRequest>>{};
      // Each request's property must be provable to the rules. Chunking also
      // respects Firestore's query/access-call limits; no properties are dropped.
      final chunks = (apartments.length / 5).ceil();
      for (var index = 0; index < chunks; index++) {
        final key = index;
        final ids = apartments
            .skip(index * 5)
            .take(5)
            .map((a) => a.id)
            .toList();
        requestSubscriptions.add(
          _collection
              .where('userId', isEqualTo: _userId)
              .where('apartmentId', whereIn: ids)
              .snapshots()
              .listen((snapshot) {
                if (current != generation) return;
                parts[key] = _toSortedList(snapshot.docs);
                if (parts.length == chunks) {
                  final requests = parts.values.expand((part) => part).toList()
                    ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
                  output.add(requests);
                }
              }, onError: output.addError),
        );
      }
    }, onError: output.addError);
    output.onCancel = () {
      generation++;
      properties.cancel();
      for (final subscription in requestSubscriptions) {
        subscription.cancel();
      }
    };
  });

  /// Read using the same bounded queries, awaiting actual data rather than the
  /// stream's initial clearing event.
  Future<List<MaintenanceRequest>> getMyRequests() async {
    final apartments = await getManageableApartments();
    final requests = <MaintenanceRequest>[];
    for (var index = 0; index < apartments.length; index += 5) {
      final snapshot = await _collection
          .where('userId', isEqualTo: _userId)
          .where(
            'apartmentId',
            whereIn: apartments.skip(index).take(5).map((a) => a.id).toList(),
          )
          .get();
      requests.addAll(_toSortedList(snapshot.docs));
    }
    return requests..sort((a, b) => a.slotStart.compareTo(b.slotStart));
  }

  /// One request, updated live. Emits null when it does not exist.
  Stream<MaintenanceRequest?> watchRequest(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MaintenanceRequest.fromMap(doc.id, doc.data()!);
    });
  }

  /// One request, read once. Returns null when it does not exist.
  Future<MaintenanceRequest?> getRequest(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return MaintenanceRequest.fromMap(doc.id, doc.data()!);
  }

  /// Returns the ID of the new request.
  Future<String> book({
    required Apartment apartment,
    required MaintenanceCategory category,
    required String description,
    required DateTime slotStart,
    required Set<MaintenanceReminder> reminders,
  }) async {
    final doc = await _collection.add({
      'userId': _userId,
      'apartmentId': apartment.id,
      'apartmentTitle': apartment.title,
      'category': category.name,
      'description': description.trim(),
      'slotStart': Timestamp.fromDate(slotStart),
      'reminders': _reminderNames(reminders),
      'status': MaintenanceStatus.scheduled.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> reschedule(
    String id,
    DateTime slotStart,
    Set<MaintenanceReminder> reminders,
  ) {
    return _collection.doc(id).update({
      'slotStart': Timestamp.fromDate(slotStart),
      'reminders': _reminderNames(reminders),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String id) {
    return _collection.doc(id).update({
      'status': MaintenanceStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> _reminderNames(Set<MaintenanceReminder> reminders) =>
      reminders.map((reminder) => reminder.name).toList();

  // Sorted here instead of with orderBy, so no Firestore index is needed.
  List<MaintenanceRequest> _toSortedList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => MaintenanceRequest.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
  }
}
