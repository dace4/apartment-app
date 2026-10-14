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
  Stream<List<AppNotification>> watchMyNotifications() => _notifications
      .where('userId', isEqualTo: _userId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
            .toList(),
      );

  /// Saves a notification for the current user (e.g. an application update).
  Future<void> add(AppNotification notification) =>
      _notifications.add({...notification.toMap(), 'userId': _userId});

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
