# US-10 — Apply immediately: technical guide

## Behavior

Apply immediately is **submission only**. It uses the same code as a normal
application: `ApplicationService.submit(..., type: ApplicationType.immediate)`
writes `applicationType: 'immediate'` and `status: 'submitted'`. No apartment
document is written, so its availability never changes.

- `ApplyViewModel.submit(details, immediately: true)` checks the Renter role
  (`canApplyImmediately`), blocks a second open application for the same
  apartment and reuses one submission ID, so a retry stores one document.
- Attachments work as for a normal application (US-15).
- The promotion of a saved application (old **Apply immediately** button on the
  application detail page) and the automatic withdrawal when another
  application reserved the apartment are removed.

## Firestore rules

- `apartments`: `allow update: if false;` the app can no longer reserve.
- `applications` create: `status == 'submitted'`, apartment `available`, and
  `applicationType` is `normal`, or `immediate` with the Renter role.
- `applications` update: only the existing edit and withdraw within 5 days.

## Existing reserved records

Old applications with `status: 'reserved'` still load and show **Reserved**;
they cannot be edited or withdrawn. Old apartments keep `availability:
'reserved'` and their `reservationApplicationId` field, which the app ignores.

## Tests

- `test/us10_immediate_application_test.dart`: submission without reservation,
  unchanged availability, retry with the same ID, attachments, required fields.
- `test/firestore/us06_us07_rules_test.mjs`: a Buyer cannot submit an immediate
  application; no client can reserve an apartment (needs the Firestore emulator).
