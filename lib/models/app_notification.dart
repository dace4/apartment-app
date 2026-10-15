import 'package:cloud_firestore/cloud_firestore.dart';

import 'rental_application.dart';

/// US 18: the three kinds of notification a user can receive.
enum NotificationType {
  newListing('New listings'),
  applicationStatus('Application status'),
  announcement('Announcements');

  const NotificationType(this.label);
  final String label;
}

/// US 18: one notification shown in the notification center.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.apartmentId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  final String? apartmentId;

  /// US 18 (task 18.3): the notification the app saves when the user's own
  /// application changes. firestore.rules only lets the app create this type.
  factory AppNotification.applicationUpdate({
    required String apartmentTitle,
    required ApplicationStatus status,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: '',
      type: NotificationType.applicationStatus,
      title: 'Application ${status.label.toLowerCase()}',
      body: 'Your application for $apartmentTitle is now: ${status.label}.',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: NotificationType.values.byName(map['type'] as String),
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] as bool? ?? false,
      apartmentId: map['apartmentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      if (apartmentId != null) 'apartmentId': apartmentId,
    };
  }
}
