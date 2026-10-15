# US-23 — Receive alerts for new offers: technical guide

## Requirements and implementation

Source requirements are US-23 and its tasks 23.1–23.4, with the Definition of
Done: user guide, technical guide, code committed to Git, completed code review
and passed acceptance criteria. The branch is `feature/US-23-new-offer-alerts`,
based on `develop` after US-18 (receive notifications) was merged.

US-23 builds on US-18: its alerts are US-18 notifications of type
`newListing`, shown in the existing notification center and controlled by its
**New listings** switch. There is no second notification system.

Architecture follows `ARCHITECTURE.md`:

| Layer | Files |
| --- | --- |
| Models | `saved_search.dart` (matching rules), `apartment_filter.dart` (`toMap` / `fromMap`), `app_notification.dart` (optional `apartmentId`) |
| Services | `saved_search_service.dart`, `apartment_service.dart` (`watchApartments`) |
| ViewModel | `saved_searches_view_model.dart`, shared and created once in `app.dart` |
| Views | `apartments_view.dart` (save button), `widgets/save_search_dialog.dart`, `profile/saved_searches_view.dart`, `profile/notifications_view.dart` (open the apartment) |
| Utils | `describeFilter()` in `formatters.dart`, `savedSearchName()` in `validators.dart` |

## US-23.1 criteria and matching rules

| Rule | Decision |
| --- | --- |
| Criteria | The existing filters (location, rent or buy, price range, rooms, surface, amenities) plus a name |
| Offer | An apartment with `availability == available` that meets every criterion (`ApartmentFilter.matches`) |
| New offer | An offer whose id is not in the search's `seenApartmentIds` |
| On save | The current offers are stored as seen: only later offers alert |
| Duplicates | Every checked offer is added to `seenApartmentIds`; the alert id is fixed |
| Opt-out | An alert is created only if the search's `alertsEnabled` and US-18's `newListing` preference are both true; otherwise the offer is only marked as seen |
| Limits | 5 searches per user (app), name of 1–40 characters (app and rules) |

`SavedSearch.isOffer`, `isNewOffer` and `findNewOffers` are pure Dart, so the
rules are unit tested without Firebase.

## US-23.2 and 23.3 data and flow

`savedSearches/{searchId}`:

| Field | Type |
| --- | --- |
| userId | string, owner's Firebase Auth UID |
| name | string, 1–40 characters |
| filter | map, `ApartmentFilter.toMap()`; `null` means no constraint |
| alertsEnabled | bool |
| seenApartmentIds | list of apartment ids, at most 1000 |
| createdAt | server timestamp |

Alerts are documents of the US-18 collection `notifications`, with the id
`{uid}_{searchId}_{apartmentId}`, `type: "newListing"` and an `apartmentId`.

The project uses the free Spark plan, so there are no Cloud Functions to
detect new offers on a server. `SavedSearchesViewModel` does it in the app:

1. It listens to `AuthService.userChanges()`, like US-17's reminders, and only
   reads Firestore for a verified user. Signing out clears the previous data.
2. It listens live to the user's searches, the `apartments` collection and the
   US-18 preferences. Matching starts only when all three are loaded, so a
   preference that is not loaded yet never sends an unwanted alert.
3. For each search, `findNewOffers` gives the new offers.
   `SavedSearchService.recordNewOffers` then writes, in **one batch**, the ids
   added to `seenApartmentIds` (`arrayUnion`) and, if both switches are on, the
   alerts. Either both are saved or neither.
4. The write sends a new snapshot of the search. A running check is never
   started twice: `_checkAgain` runs it once more afterwards, and it then finds
   nothing new.
5. If a write fails (for example rules not published), checking stops until the
   next sign-in instead of retrying in a loop.

Duplicates are prevented twice: by the seen list, and by the fixed alert id,
which a second write cannot create again (two devices of the same user).

Limit: offers are only detected while the app runs. An offer published while
the app is closed alerts at the next launch, because it is still unseen. There
are no push notifications.

## Security rules

`firestore.rules`:

- `savedSearches`: read, create and delete by the verified owner only. The
  document must have exactly the fields above. After creation, only
  `alertsEnabled` and `seenApartmentIds` can change.
- `notifications` (US-18, `validNotification`): besides `applicationStatus`,
  the app may create `newListing` notifications for its own user, with a
  string `apartmentId` and an id starting with the user's UID. A user can
  therefore not alert someone else. Titles stay limited to 120 characters; the
  ViewModel shortens longer ones.

No index is needed: the queries only filter on `userId`.

Rules must be published by copying the whole `firestore.rules` into the
Firebase console (Firestore Database → Rules → Publish).

## Changes to US-18 files

- `app_notification.dart`: optional `apartmentId`, written only when set, so
  existing notifications are unchanged.
- `notifications_view.dart`: tapping a notification with an `apartmentId` opens
  that apartment.
- `firestore.rules`: `validNotification` also accepts `newListing` alerts.

## US-23.4 tests

`test/us23_new_offer_alerts_test.dart` replaces Firebase with fake services and
covers: matching rules, the filter round trip, one alert per new offer even when
the same listings arrive again, no alert for non-matching offers, opt-out per
search and through **New listings**, no alert for offers existing when saving,
and the 5-search limit.

Run `flutter analyze` and `flutter test`. Device checks on Android and the
Firestore rules are covered by the acceptance walkthrough in the user guide;
they are not automated.
