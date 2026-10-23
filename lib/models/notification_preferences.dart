import 'app_notification.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.newListing = true,
    this.applicationStatus = true,
    this.announcement = true,
    this.visit = true,
    this.maintenance = true,
    this.message = true,
    this.newApplication = true,
  });
  final bool newListing;
  final bool applicationStatus;
  final bool announcement;

  /// US-20: visits of the user's apartments.
  final bool visit;

  /// US-17: reminders before repair and maintenance services.
  final bool maintenance;

  /// US 18.2: messages and applications an owner receives.
  final bool message;
  final bool newApplication;

  bool isEnabled(NotificationType type) => switch (type) {
    NotificationType.newListing => newListing,
    NotificationType.applicationStatus => applicationStatus,
    NotificationType.announcement => announcement,
    NotificationType.visit => visit,
    NotificationType.maintenance => maintenance,
    NotificationType.message => message,
    NotificationType.newApplication => newApplication,
  };

  //Return new pre with 1 switch changed + keep other
  NotificationPreferences copyWithType(NotificationType type, bool enabled) {
    return NotificationPreferences(
      newListing: type == NotificationType.newListing ? enabled : newListing,
      applicationStatus: type == NotificationType.applicationStatus
          ? enabled
          : applicationStatus,
      announcement: type == NotificationType.announcement
          ? enabled
          : announcement,
      visit: type == NotificationType.visit ? enabled : visit,
      maintenance: type == NotificationType.maintenance
          ? enabled
          : maintenance,
      message: type == NotificationType.message ? enabled : message,
      newApplication: type == NotificationType.newApplication
          ? enabled
          : newApplication,
    );
  }

  /// A user who never changed a switch receives every kind (all opted in).
  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    return NotificationPreferences(
      newListing: map?['newListing'] as bool? ?? true,
      applicationStatus: map?['applicationStatus'] as bool? ?? true,
      announcement: map?['announcement'] as bool? ?? true,
      visit: map?['visit'] as bool? ?? true,
      maintenance: map?['maintenance'] as bool? ?? true,
      message: map?['message'] as bool? ?? true,
      newApplication: map?['newApplication'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'newListing': newListing,
      'applicationStatus': applicationStatus,
      'announcement': announcement,
      'visit': visit,
      'maintenance': maintenance,
      'message': message,
      'newApplication': newApplication,
    };
  }
}
