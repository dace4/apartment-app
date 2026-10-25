# US-17 — Schedule repair and maintenance: technical guide

## Requirements

US-17 (Property Manager): "Schedule repair and maintenance, so that I can
organize maintenances depending on my disponibilities". Acceptance
criterion: **System sends notification before scheduled service**.
Branch: `feature/US-17-maintenance-notifications`.

| Task | Implementation |
| --- | --- |
| 17.1 Restrict scheduling to homeowners and assigned property managers | Since the Sprint 3 review: **property managers only**, for their assigned apartments. Route access (`AuthViewModel.canAccess`: `isPropertyManager`), assigned apartments only (`MaintenanceService.getManageableApartments`: `managerIds`), re-check before every save (`MaintenanceBookingViewModel._save`), and `firestore.rules` (`assigned(apartmentId)`: property manager listed in `managerIds`). Explanatory empty state when the user is assigned to no apartment |
| 17.2 Replace time dropdown with a scrolling wheel using valid slots | `CupertinoPicker` in `maintenance_booking_view.dart`, fed by `availableSlots` (free, bookable slots only); choosing a date selects its first free time |
| 17.3 Connect upcoming maintenance and reminders to in-app notifications | `MaintenanceRemindersViewModel` saves each due reminder once as a US 18 notification of type `maintenance` |
| 17.4 Test booking, rescheduling, cancellation, permissions and reminder timing | `test/us17_maintenance_test.dart` |

## Architecture (ARCHITECTURE.md)

| Layer | Change |
| --- | --- |
| Models | `MaintenanceRequest.latestDueReminder(now)`; `NotificationType.maintenance`; `AppNotification.maintenanceId` and `AppNotification.maintenanceReminder(...)`; `NotificationPreferences.maintenance` |
| Services | `NotificationService.addWithFixedId` |
| ViewModels | `MaintenanceRemindersViewModel` (shared, app.dart) and `MaintenanceBookingViewModel` take optional services and a clock, for tests |
| Views | Time wheel and empty state in `maintenance_booking_view.dart`; maintenance icon, switch and link in `notifications_view.dart` |
| Rules | `validMaintenanceNotification` and the optional `maintenance` preference in `firestore.rules` |

## Reminder notifications (17.3)

| Rule | Decision |
| --- | --- |
| When | A reminder is due from `slotStart - reminder.before` until `slotStart` (`MaintenanceRequest.dueReminders`) |
| Which | Per service, only the due reminder closest to the service (`latestDueReminder`), as for the banner |
| Who sends | The app of the user who booked, while it runs: on new data and every minute (`Timer.periodic`). There is no server push |
| Duplicates | Document id `<uid>_maintenance_<requestId>_<reminder>`; sent only once the user's notification ids are loaded; the rules refuse to overwrite an existing notification |
| Opt-out | Always saved to the inbox (Sprint 3 review); the `maintenance` switch only hides it from the red badge |
| Opening | Tapping the notification opens `AppRoutes.maintenanceDetail(maintenanceId)` |

### Firestore rules

A `maintenance` notification is accepted only for the signed-in user, with a
`maintenanceId` of a request that user booked, no `apartmentId`, and the
fixed id above. `maintenanceId` is refused on every other notification type.
`notificationPreferences` accepts an optional boolean `maintenance`.

**The updated `firestore.rules` must be deployed** (Firebase Console →
Firestore → Rules → Publish) before reminder notifications can be saved.

## Tests

`flutter test test/us17_maintenance_test.dart` covers: properties limited to
those owned or managed, booking refused after losing the assignment, the
wheel's free slots (booked, lunch break, weekend, today), same-date choice,
booking, rescheduling, change limits and cancellation, reminder timing, and
reminder notifications (sent once with a fixed id, not when existing, not
when opted out, not before time).
