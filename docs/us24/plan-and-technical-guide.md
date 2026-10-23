# US-24 — Add apartments and pictures

## References and requirements

- `AGENTS.md`: story identity, preservation, Git workflow and Definition of Done.
- `ARCHITECTURE.md`: MVVM layers, screen-owned state, services, route constants,
  View-owned navigation, and error-state conventions.
- `DATA_MODEL.md`: apartment schema, ownership, availability and roles.
- `output/sprint-3-planning/ProductBacklog_FIG_2026_Apartment_S3_final.xlsx`
  in the primary checkout: read all sheets; `ProductBacklog_360` US 24 says a
  homeowner can fill fields, submit and view an apartment with at least three
  pictures. `Sprint 3` supplies tasks 24.1–24.5 (13 draft hours; owners and dates
  unassigned). `Done Definition` requires guides, Git commit, review and acceptance.
- Existing `lib/models/apartment.dart`, `lib/services/apartment_service.dart`,
  `lib/services/document_service.dart`, `lib/services/file_picker_service.dart`,
  `lib/view_models/auth_view_model.dart`, `lib/router/app_router.dart`,
  `lib/router/app_routes.dart`, apartment Views/widgets and `firestore.rules`.

The supplied task table takes precedence over planning documents. No unrelated
Sprint 3 fixes are included. No remote synchronization, push, PR, deployment or
merge was performed; freshness of local `develop` relative to origin is unverified.
The implementation is isolated from the primary checkout's staged guide work in
`.worktrees/us-24`, branch `feature/US-24-add-apartments-and-pictures`.

## Plan and implementation

| Task | Implementation |
| --- | --- |
| 24.1 | Extend `Apartment` with ordered `imageUrls`, retaining `imageUrl`; define required fields and limits in `utils/listing_validation.dart` and `DATA_MODEL.md`. |
| 24.2 | Add `CreateApartmentView` and its screen-owned `CreateApartmentViewModel`; expose Add apartment only to verified homeowners; register static `/apartments/new` before `:id`. |
| 24.3 | Normalize JPEG/PNG through `ListingImageService`; publish atomically in `ApartmentService`; force authenticated creator ownership, empty managers, available status and server timestamp; protect creation with Firestore rules. |
| 24.4 | Add swipe/previous/next gallery, inline-image rendering and legacy fallback; prepare three synthetic gallery listings and one legacy listing under `test/fixtures/`, with a local-demo-only seeder. |
| 24.5 | Test required fields, minimum/distinct/bounded pictures, authorization, ownership, legacy data, invalid images, cancellation, publication failure, duplicate taps and retry ID reuse; verify actual rules with the emulator. |

## Data and failure behaviour

`listing_validation.dart` and Firestore rules define the same input ranges.
New listings start available. Users cannot set an arbitrary owner or managers.
Existing property assignments and reservation updates remain protected. The
verified-email gate still precedes role access.

Original JPEG/PNG inputs are capped at 10 MiB and 32 megapixels. Processing runs
in an isolate, bakes camera orientation, resizes to at most 1280 pixels on the
long edge (reducing further if required), and strips metadata by JPEG re-encoding.
The form accepts 3–6 distinct encoded images, each at most 96 KiB after processing.
The first is the cover. Six images plus the duplicated cover consume about
896 KiB plus a small amount of text/metadata, below Firestore's 1 MiB limit.
This deliberately follows the project's existing bounded Firestore file storage;
no new bucket, plugin or Firebase configuration is introduced. Reading list
records includes photos; this approach is appropriate for this bounded course
feature, not a large high-resolution image catalogue.

Rules validate strings, count, distinctness, encoded size and JPEG data-URI shape.
They cannot decode bytes or establish that different pictures show different
subjects. The app checks actual decodability; unreadable or unavailable stored
photos display the existing home placeholder. Synthetic fixtures are clearly
labelled and are not real property advertisements.

All pictures and listing metadata commit together, so a failed transaction leaves
no orphan files or partially published listing. A transaction requires connectivity;
there is no offline draft persistence. Failed actions preserve the open form and
pictures. A stable generated ID prevents duplicate publications after uncertain
responses; retry succeeds only when the already-created listing matches the same
creator and content. Closing the form discards its in-memory draft.

## Reproduce automated checks

```powershell
flutter pub get --offline
flutter analyze --no-pub
flutter test --no-pub
```

Start the installed Firestore emulator with this worktree's `firestore.rules`,
project `demo-homeflow-us24`, host `127.0.0.1`, port `8244`. On this Windows host,
Java's default temporary socket path failed. Passing the following JVM argument
with an existing local directory resolves it without changing machine settings:

```text
-Djdk.net.unixdomain.tmpdir=C:/Projects/MobileDev/apartment-app/.worktrees/us-24/.local-java
```

Then run:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8244'
node --test test/firestore/us24_rules_test.mjs
node test/firestore/us24_seed.mjs
node --test --test-concurrency=1 test/firestore/us06_us07_rules_test.mjs test/firestore/us11_rules_test.mjs test/firestore/us15_rules_test.mjs
```

The US-24 scripts refuse non-local hosts and use a fixed demo project. Seeder
uses the emulator-only admin token; never use it for production. It overwrites
only the four named synthetic demo fixtures and their sample homeowner profile.

For optional local UI preview captures:

```powershell
$env:US24_CAPTURE='1'
flutter test --no-pub test/us24_listings_test.dart
```

Phone/tablet captures are written to `tmp/us24/`. They are generated QA artifacts,
not test golden baselines. See `verification.md` for actual results and outstanding
checks. Firebase rules remain local until deployment is explicitly authorized.
