# US-16 — Track and review applications: technical guide

## Ownership

- An application belongs to its applicant (`userId`).
- It is reviewed by the apartment's owner (Homeowner role and
  `apartments.ownerId == uid`) or an assigned manager (Property Manager role and
  `uid in apartments.managerIds`), the same `manages()` check as US-07
  maintenance.

## Status transitions

`ApplicationStatus` (labels in brackets):

```
submitted (Applied) → received (Received) → underReview (In review) → accepted | rejected
```

- `ApplicationStatus.reviewSteps` gives the next statuses; firestore.rules
  `validReview()` allows exactly the same ones.
- `isOpen` (edit/withdraw by the applicant within 5 days) is true for
  `submitted`, `received` and `underReview`; the rules' `changeable()` matches.
- `withdrawn` is set by the applicant; `reserved` only exists on records from
  before the US 10 fix.

## Code (MVVM)

| Layer | File | Role |
| --- | --- | --- |
| Model | `models/rental_application.dart` | statuses, labels, `reviewSteps` |
| Service | `services/apartment_service.dart` | `getManagedApartments(user)` |
| Service | `services/application_service.dart` | `getApplicationsForApartments(ids)` (5 IDs per query, so the rules can check each apartment), `review(application, status)` |
| ViewModel | `view_models/inbox_view_model.dart` | inbox list |
| ViewModel | `view_models/review_application_view_model.dart` | detail, `nextSteps`, `review()` |
| View | `views/profile/inbox_view.dart`, `review_application_view.dart` | routes `/profile/inbox` and `/profile/inbox/applications/:id` |

`AuthViewModel.canAccess` allows `/profile/inbox` for Homeowner and Property
Manager only; the Profile page shows the **Inbox** entry the same way.

## Notifications

`ApplicationService.review` writes the new status and an `applicationStatus`
notification for the applicant in one batch. The notification has an
`applicationId`. The rules accept a notification for another user only when the
writer manages that application's apartment and the application's `updatedAt`
equals `request.time`, i.e. in the same batch as a status change. The
applicant's US-18 preferences hide it when "Application status" is off.

## Tests

- `test/us16_application_review_test.dart`: labels, transitions, 5-day rule,
  inbox ownership, review steps and notifications (fake Firestore).
- `test/firestore/us06_us07_rules_test.mjs`: reviewer access, step order,
  notification only with a status change (needs the Firestore emulator).
