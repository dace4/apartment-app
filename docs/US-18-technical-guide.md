# US 18 — Receive notifications: technical guide

## Requirements

US 18 (User): "Receive notifications, so that I am updated on new listings,
application status, and important announcements". Acceptance criterion:
**User must be able to opt in, opt out of notifications at any time in the
profile page**. Sprint 3 branch: `feature/US-18-notification-events`.

| Task | Implementation |
| --- | --- |
| 18.1 Extend event types, recipients, destinations and profile preferences | `NotificationType.message` and `newApplication`; `AppNotification.applicationId` / `messageId`; optional `message` and `newApplication` preferences (missing means on) |
| 18.2 Owner notifications for messages and new applications; applicant notifications for status changes | `MessageService.send` (batch) and `ApplicationService.submit` (transaction) notify the owner in the same write; status changes already notify the applicant (`ApplicationService.review`, US 16) |
| 18.3 Shared unread count and red Profile badge | `NotificationsViewModel.alertCount` (shared, app.dart) shown as `Badge.count` on the Profile tab and the Notifications tile; `unreadCount` (all kinds) in the inbox heading |
| 18.4 Upcoming-event notifications and read handling | `VisitRemindersViewModel` (shared, app.dart) saves "Visit tomorrow" once per visit; `NotificationsViewModel.destinationFor` / `open` mark as read and open the page. Maintenance reminders: US-17 |
| 18.5 Tests | `test/us18_notification_events_test.dart`, plus `us18_notifications_test.dart` and `us17_maintenance_test.dart` |

## Switches (Sprint 3 review)

The Product Owner decided that the inbox always shows **every**
notification. The switches ("Alert me about") only control the alert: the
red badge counts unread notifications of the kinds that are switched on
(`alertCount`). Reminders and new-offer alerts are always stored; a saved
search's own "Alerts for new offers" switch still turns that search off.

## Recipients and destinations

| Type | Created by | Recipient (`userId`) | Link field → route |
| --- | --- | --- | --- |
| `applicationStatus` | Owner/manager reviewing (US 16) | Applicant | `applicationId` → `applicationDetail` |
| `newApplication` | Applicant submitting | `apartments.ownerId` | `applicationId` → `inboxApplication` |
| `message` | Sender | `advertiserMessages.advertiserId` | `messageId` → `inboxMessage` |
| `visit` (booked/cancelled) | Visitor (US-20) | Owner | `visitId` → `inboxVisit` |
| `visit` (reminder) | Visitor's app | Visitor | `apartmentId` → `apartmentDetail` |
| `maintenance` | Owner's/manager's app (US-17) | Same user | `maintenanceId` → `maintenanceDetail` |
| `newListing` | Saved-search owner's app (US-23) | Same user | `apartmentId` → `apartmentDetail` |
| `announcement` | Firebase console | Any user | — |

## Duplicate prevention and isolation

- Reminders use fixed document ids (`<uid>_visitReminder_<visitId>`,
  `<uid>_maintenance_<requestId>_<reminder>`); the app sends one only after
  the user's notification ids and preferences are loaded, and the rules
  refuse to overwrite an existing notification.
- Owner notifications are written in the same batch or transaction as the
  message or application; the rules check with `getAfter` that the
  message's `createdAt` or the application's `submittedAt` equals
  `request.time`, that the sender is the signed-in user and that the
  recipient is the advertiser or the apartment's owner. A retried
  application submission returns before writing, so it never notifies twice.
- Every user only lists and reads notifications whose `userId` is theirs;
  only `isRead` can change, to `true`; nothing can be deleted.
- Visit reminders are only read and sent for renters and buyers.

**The updated `firestore.rules` must be deployed** together with this
change: sending a message or submitting an application writes a
notification in the same batch, which older rules refuse.

## Limitations

Notifications are in-app only (the acceptance criterion's "preferred
communication method (in app)"); reminders are created while the app is
running. Push notifications (Firebase Cloud Messaging) would need a server.
