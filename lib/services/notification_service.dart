import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/notification_preferences.dart';

/// US 18: Firebase access to the current user's notifications and
/// notification preferences.
class NotificationService {
  final _notifications = FirebaseFirestore.instance.collection('notifications');
  final _preferences = FirebaseFirestore.instance.collection(
    'notificationPreferences',
  );

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  /// Live list of the user's notifications; the ViewModel sorts and filters it.
  /// Kinds the app no longer has (the retired US-17 maintenance reminders)
  /// are left out.
  Stream<List<AppNotification>> watchMyNotifications() => _notifications
      .where('userId', isEqualTo: _userId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .where((doc) => _knownTypes.contains(doc.data()['type']))
            .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
            .toList(),
      );

  static final _knownTypes = NotificationType.values.map((t) => t.name).toSet();

  /// Saves a notification for the current user (e.g. an application update).
  Future<void> add(AppNotification notification) =>
      _notifications.add({...notification.toMap(), 'userId': _userId});

  /// US 18.4: saves a notification under the fixed id `<uid>_<id>`, so the
  /// same reminder is stored at most once (firestore.rules refuse to
  /// overwrite it).
  Future<void> addWithFixedId(AppNotification notification) => _notifications
      .doc('${_userId}_${notification.id}')
      .set({...notification.toMap(), 'userId': _userId});

  Future<void> markAsRead(String notificationId) =>
      _notifications.doc(notificationId).update({'isRead': true});

  /// Live preferences: one document per user, named after the user ID.
  Stream<NotificationPreferences> watchPreferences() => _preferences
      .doc(_userId)
      .snapshots()
      .map((doc) => NotificationPreferences.fromMap(doc.data()));

  Future<void> savePreferences(NotificationPreferences preferences) =>
      _preferences.doc(_userId).set(preferences.toMap());
}
