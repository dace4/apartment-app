import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/apartment.dart';
import '../models/app_user.dart';
import '../models/visit.dart';
import '../utils/formatters.dart';
import '../utils/visit_schedule.dart';
import 'visit_exception.dart';

/// US-20: apartment visits. A booked slot is stored twice:
/// - `visitSlots/{slotId}` says the slot is taken, without saying by whom,
///   so every user can see which slots are free;
/// - `visits/{id}` holds the visit itself and only its visitor can read it.
/// The apartment's owner is notified in the same write.
class VisitService {
  VisitService({FirebaseFirestore? firestore, AppUser? Function()? currentUser})
    : _db = firestore ?? FirebaseFirestore.instance,
      _currentUser = currentUser ?? _firebaseUser;
  final FirebaseFirestore _db;
  final AppUser? Function() _currentUser;
  CollectionReference<Map<String, dynamic>> get _visits =>
      _db.collection('visits');
  CollectionReference<Map<String, dynamic>> get _slots =>
      _db.collection('visitSlots');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  static const takenMessage =
      'This time slot was just taken. Choose another one.';

  static AppUser? _firebaseUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? null
        : AppUser(
            id: user.uid,
            email: user.email ?? '',
            emailVerified: user.emailVerified,
          );
  }

  /// The signed-in user's ID, or null when nobody is logged in.
  String? get currentUserId => _currentUser()?.id;

  AppUser get _user {
    final user = _currentUser();
    if (user == null || !user.emailVerified) {
      throw const VisitException(
        'Log in with a verified email to book a visit.',
      );
    }
    return user;
  }

  /// The start of every taken slot of an apartment, updated live.
  Stream<Set<DateTime>> watchTakenSlots(String apartmentId) => _slots
      .where('apartmentId', isEqualTo: apartmentId)
      .snapshots()
      .map(
        (snapshot) => {
          for (final doc in snapshot.docs)
            (doc.data()['slotStart'] as Timestamp).toDate(),
        },
      );

  /// The user's visits, soonest first, updated live.
  Stream<List<Visit>> watchMyVisits() => _visits
      .where('visitorId', isEqualTo: _user.id)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => Visit.fromMap(doc.id, doc.data()))
                .toList()
              // Sorted here instead of with orderBy, so no index is needed.
              ..sort((a, b) => a.slotStart.compareTo(b.slotStart)),
      );

  /// Books [slotStart] and notifies the owner. Throws a [VisitException]
  /// with [takenMessage] when someone else booked the slot first.
  Future<Visit> book(Apartment apartment, DateTime slotStart) async {
    final user = _user;
    final ownerId = apartment.ownerId;
    if (ownerId == null) {
      throw const VisitException('This apartment cannot be visited yet.');
    }
    final slotId = VisitSchedule.slotId(apartment.id, slotStart);
    final slotRef = _slots.doc(slotId);
    final visitRef = _visits.doc();
    final slotEnd = slotStart.add(Visit.slotLength);
    try {
      // A transaction re-reads the slot if another booking wrote it
      // meanwhile, and firestore.rules refuse to overwrite a taken slot.
      await _db.runTransaction((transaction) async {
        final slot = await transaction.get(slotRef);
        if (slot.exists) throw const VisitException(takenMessage);
        transaction.set(visitRef, {
          'apartmentId': apartment.id,
          'apartmentTitle': apartment.title,
          'ownerId': ownerId,
          'visitorId': user.id,
          'visitorEmail': user.email,
          'slotId': slotId,
          'slotStart': Timestamp.fromDate(slotStart),
          'status': VisitStatus.booked.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(slotRef, {
          'apartmentId': apartment.id,
          'slotStart': Timestamp.fromDate(slotStart),
          'visitId': visitRef.id,
        });
        transaction.set(
          _notifications.doc(),
          _ownerNotification(
            ownerId: ownerId,
            apartmentId: apartment.id,
            visitId: visitRef.id,
            title: 'New visit: ${apartment.title}',
            body:
                '${user.email} booked a visit on '
                '${formatTimeSlot(slotStart, slotEnd)}.',
          ),
        );
      }, timeout: const Duration(seconds: 20));
    } on VisitException {
      rethrow;
    } on FirebaseException catch (e) {
      throw VisitException(
        e.code == 'permission-denied'
            ? 'This time slot is no longer available. Choose another one.'
            : 'Could not book the visit. Check your connection and try again.',
      );
    }
    return Visit(
      id: visitRef.id,
      apartmentId: apartment.id,
      apartmentTitle: apartment.title,
      ownerId: ownerId,
      visitorId: user.id,
      visitorEmail: user.email,
      slotId: slotId,
      slotStart: slotStart,
      status: VisitStatus.booked,
    );
  }

  /// One visit, updated live (e.g. when the visitor cancels it). Readable by
  /// its visitor and the apartment's owner. Emits null when it does not
  /// exist.
  Stream<Visit?> watchVisit(String id) =>
      _visits.doc(id).snapshots().map((doc) {
        if (!doc.exists) return null;
        return Visit.fromMap(doc.id, doc.data()!);
      });

  /// Cancels [visit], frees its slot and notifies the owner, all or nothing.
  Future<void> cancel(Visit visit) async {
    final user = _user;
    final batch = _db.batch();
    batch.update(_visits.doc(visit.id), {
      'status': VisitStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_slots.doc(visit.slotId));
    batch.set(
      _notifications.doc(),
      _ownerNotification(
        ownerId: visit.ownerId,
        apartmentId: visit.apartmentId,
        visitId: visit.id,
        title: 'Visit cancelled: ${visit.apartmentTitle}',
        body:
            '${user.email} cancelled the visit on '
            '${formatTimeSlot(visit.slotStart, visit.slotEnd)}. '
            'The time slot is free again.',
      ),
    );
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw VisitException(
        e.code == 'permission-denied'
            ? 'This visit can no longer be cancelled.'
            : 'Could not cancel the visit. Check your connection and try '
                  'again.',
      );
    }
  }

  Map<String, dynamic> _ownerNotification({
    required String ownerId,
    required String apartmentId,
    required String visitId,
    required String title,
    required String body,
  }) => {
    'userId': ownerId,
    'type': 'visit',
    // firestore.rules accept titles of at most 120 characters.
    'title': title.length <= 120 ? title : '${title.substring(0, 119)}…',
    'body': body,
    'createdAt': Timestamp.now(),
    'isRead': false,
    // Opens the apartment when the owner taps the notification.
    'apartmentId': apartmentId,
    'visitId': visitId,
  };
}
