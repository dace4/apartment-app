# US-12 — Owner and manager inbox: technical guide

## Ownership

A message in `advertiserMessages` can be read by its sender (`senderId`), the
addressed advertiser (`advertiserId`), and the owner or assigned managers of
its apartment (`manages(apartmentId)`, as for US-16 applications). Nobody can
change or delete it.

The recipient (`advertiserId`) is the `advertiserContacts` entry of the
apartment or, for listings published in the app (US-24, no contact entry), the
apartment's `ownerId`. `ContactAdvertiserViewModel` falls back to the owner and
`validMessage()` accepts either.

## Code (MVVM)

| Layer | File | Role |
| --- | --- | --- |
| Model | `models/advertiser_message.dart` | `AdvertiserMessage.fromMap` with `id`, `senderEmail`, `createdAt` |
| Service | `services/message_service.dart` | `getMessagesForApartments(ids)` (5 IDs per query, newest first), `getMessage(id)`; Firestore can be injected for tests |
| ViewModel | `view_models/inbox_view_model.dart` | loads managed apartments, then applications and messages |
| ViewModel | `view_models/message_detail_view_model.dart` | one message |
| View | `views/profile/inbox_view.dart` | tabs Applications / Messages |
| View | `views/profile/message_detail_view.dart` | route `/profile/inbox/messages/:id` |

Access: `AuthViewModel.canAccess` allows everything under `/profile/inbox` for
Homeowner and Admin only.

## Firestore rules

`advertiserMessages` get and list also allow `messageReviewer()`: a management
role and `manages(resource.data.apartmentId)`. Inbox queries filter on
`apartmentId in [...]` so the rules can check each apartment.

## Tests

- `test/us12_owner_inbox_test.dart`: only managed apartments, newest first,
  message detail (fake Firestore).
- `test/firestore/us06_us07_rules_test.mjs`: manager can read, stranger cannot
  (needs the Firestore emulator).
