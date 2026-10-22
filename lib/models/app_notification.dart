import 'package:cloud_firestore/cloud_firestore.dart';

import 'maintenance_request.dart';
import 'visit.dart';

/// US 18: the kinds of notification a user can receive.
enum NotificationType {
  newListing('New listings'),
  applicationStatus('Application status'),
  announcement('Announcements'),

  /// US-20: a visit of the user's apartment was booked or cancelled.
  visit('Visits'),

  /// US-17: a reminder before a scheduled repair or maintenance service.
  maintenance('Maintenance'),

  /// US 18.2: an owner received a message about their apartment.
  message('Messages'),

  /// US 18.2: an owner received an application for their apartment.
  newApplication('New applications');

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
    this.visitId,
    this.maintenanceId,
    this.applicationId,
    this.messageId,
  });

  /// US 18.4: the visitor's reminder the day before a visit. Its [id] is
  /// fixed per visit, so it is never stored twice. It opens the apartment,
  /// which shows the visit.
  factory AppNotification.visitReminder(
    Visit visit, {
    required DateTime createdAt,
  }) {
    final title = 'Visit tomorrow: ${visit.apartmentTitle}';
    return AppNotification(
      id: visitReminderId(visit.id),
      type: NotificationType.visit,
      // firestore.rules accept titles of at most 120 characters.
      title: title.length <= 120 ? title : '${title.substring(0, 119)}…',
      body:
          'Your visit starts on ${visit.slotStart.day}.${visit.slotStart.month}.'
          '${visit.slotStart.year} at ${_time(visit.slotStart)}.',
      createdAt: createdAt,
      apartmentId: visit.apartmentId,
    );
  }

  /// The part of the document id after the user id (`<uid>_<this>`).
  static String visitReminderId(String visitId) => 'visitReminder_$visitId';

  static String _time(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// US-17.3: the reminder for [request]. Its [id] is fixed per request and
  /// reminder, so the same reminder is never stored twice.
  factory AppNotification.maintenanceReminder(
    MaintenanceRequest request,
    MaintenanceReminder reminder, {
    required DateTime createdAt,
  }) {
    return AppNotification(
      id: maintenanceReminderId(request.id, reminder),
      type: NotificationType.maintenance,
      title: '${request.category.label} service ${_when(reminder)}',
      body: '${request.apartmentTitle}: ${request.description}',
      createdAt: createdAt,
      maintenanceId: request.id,
    );
  }

  /// The part of the document id after the user id (`<uid>_<this>`).
  static String maintenanceReminderId(
    String requestId,
    MaintenanceReminder reminder,
  ) => 'maintenance_${requestId}_${reminder.name}';

  static String _when(MaintenanceReminder reminder) => switch (reminder) {
    MaintenanceReminder.oneDay => 'tomorrow',
    MaintenanceReminder.oneHour => 'in 1 hour',
    MaintenanceReminder.fiveMinutes => 'in 5 minutes',
  };

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  final String? apartmentId;

  /// US-20: the visit that was booked or cancelled; opens its details.
  final String? visitId;

  /// US-17: the maintenance service of a reminder; opens its details.
  final String? maintenanceId;

  /// US 16 / 18.2: the application whose status changed (for the applicant)
  /// or that was received (for the owner).
  final String? applicationId;

  /// US 18.2: the message an owner received.
  final String? messageId;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: NotificationType.values.byName(map['type'] as String),
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] as bool? ?? false,
      apartmentId: map['apartmentId'] as String?,
      visitId: map['visitId'] as String?,
      maintenanceId: map['maintenanceId'] as String?,
      applicationId: map['applicationId'] as String?,
      messageId: map['messageId'] as String?,
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
      if (visitId != null) 'visitId': visitId,
      if (maintenanceId != null) 'maintenanceId': maintenanceId,
      if (applicationId != null) 'applicationId': applicationId,
      if (messageId != null) 'messageId': messageId,
    };
  }
}
