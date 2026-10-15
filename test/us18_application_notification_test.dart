import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/app_notification.dart';
import 'package:appartment_app_group_2/models/rental_application.dart';

void main() {
  group('US-18 application status notifications', () {
    test('submitting creates an unread application-status notification', () {
      final notification = AppNotification.applicationUpdate(
        apartmentTitle: 'Sunny studio',
        status: ApplicationStatus.submitted,
        createdAt: DateTime(2026, 10, 15),
      );

      expect(notification.type, NotificationType.applicationStatus);
      expect(notification.isRead, isFalse);
      expect(notification.title, 'Application submitted');
      expect(notification.body, contains('Sunny studio'));
    });

    test('withdrawing names the new status', () {
      final notification = AppNotification.applicationUpdate(
        apartmentTitle: 'Sunny studio',
        status: ApplicationStatus.withdrawn,
      );

      expect(notification.title, 'Application withdrawn');
      expect(notification.body, endsWith('Withdrawn.'));
    });

    test('saves exactly the fields firestore.rules allows', () {
      final map = AppNotification.applicationUpdate(
        apartmentTitle: 'Sunny studio',
        status: ApplicationStatus.submitted,
      ).toMap();

      // The service adds userId; the rules require exactly these + userId.
      expect(map.keys.toSet(), {
        'type',
        'title',
        'body',
        'createdAt',
        'isRead',
      });
      expect(map['type'], 'applicationStatus');
      expect(map['isRead'], isFalse);
    });
  });
}
