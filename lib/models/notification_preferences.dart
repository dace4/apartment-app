import 'app_notification.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.newListing = true,
    this.applicationStatus = true,
    this.announcement = true,
  });
  final bool newListing;
  final bool applicationStatus;
  final bool announcement;

  bool isEnabled(NotificationType type) => switch (type) {
    NotificationType.newListing => newListing,
    NotificationType.applicationStatus => applicationStatus,
    NotificationType.announcement => announcement,
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
    );
  }

  /// A user who never changed a switch receives every kind (all opted in).
  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    return NotificationPreferences(
      newListing: map?['newListing'] as bool? ?? true,
      applicationStatus: map?['applicationStatus'] as bool? ?? true,
      announcement: map?['announcement'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'newListing': newListing,
      'applicationStatus': applicationStatus,
      'announcement': announcement,
    };
  }
}
