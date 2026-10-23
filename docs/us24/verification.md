# US-24 verification — 18 October 2026

## Completed local checks

- `flutter analyze --no-pub`: no issues.
- Final full Flutter suite: 65 tests passed, including all 11 US-24 tests.
- Final US-24 tests: 11 passed, including fixture validation and form publication
  at 390×844 and 800×1000. Failed saves retain input/photos; retry uses the same ID;
  successful submission navigates to details.
- Real Firestore emulator: all 5 US-24 scenarios passed (6 tests including parent).
  Verified homeowner publication, signed-out/unverified/renter/manager denial,
  minimum three/distinct/bounded pictures, field/ownership restrictions, and
  immutable existing listings.
- Existing US-06/07, US-11 and US-15 rules: 19 tests passed sequentially. A first
  parallel run collided on their shared demo fixtures; sequential rerun passed.
- Four synthetic fixtures seeded successfully into local `demo-homeflow-us24`.
- `flutter run --no-pub -d emulator-5554 --no-resident`: debug APK built, installed
  and launched on Android 16 / API 36 emulator. Firebase initialized and files
  synced. The host required the documented Java temporary-socket workaround.
- Phone/tablet widget captures inspected for layout; these use Flutter's test
  font and do not replace a real-device typography or accessibility review.
- `git diff --check`: passed.

## Acceptance walkthrough for team/PO

1. Verified homeowner opens Add apartment; renter/buyer/property-manager-only
   accounts cannot open `/apartments/new`; unverified accounts go to verification.
2. Empty required fields and 0–2 pictures prevent publication with a clear error.
3. With valid rent/sale fields and at least three distinct JPEG/PNG pictures,
   Publish confirms success and opens details. Verify all gallery pictures and
   the cover on list/comparison screens after reopening the listing.
4. Cancel selection, select corrupt/unsupported/oversize images, remove a photo,
   and retry failed publication. Input stays available; no partial listing/files
   or duplicate listing is created.
5. Reopen a legacy `imageUrl`-only listing; its picture remains visible. Unreadable
   images show the home placeholder.
6. Confirm only the creator owns the new listing, managers start empty, status is
   available, and an attempted ownership/manager change on an existing listing fails.

The publication flow was verified with widget tests, fake Firestore persistence,
and real emulator rules. Android startup passed; manual Android publication with
photo-picker interaction against an explicitly configured test backend and
physical-device checks remain outstanding. Production publication was not attempted.

## Delivery status

Local implementation, automated coverage, guides and Android startup are complete.
The implementation is committed on the US-24 branch. Peer review (including a
teammate pulling/running the branch), protected-branch integration, full manual
acceptance and separate PO acceptance remain outstanding. No push, PR, Firebase
rules deployment or merge was performed. Until the rules are separately reviewed
and deployed, the production backend continues to reject new listing creation.
