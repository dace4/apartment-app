# US-15 — Upload application documents: technical guide

Requirements: supplied US-15 tasks 15.1–15.4 and the approved plan. No additional
sprint workbook was supplied. This implementation follows `ARCHITECTURE.md` MVVM,
preserves US-06/07 verified-email access, and leaves teammates' flows intact.

## Files and validation (15.1–15.3)

`file_picker` selects up to ten files. Selection produces immutable `DocumentUpload`
objects with stable IDs and a captured owner UID. `DocumentsViewModel` owns upload
state and per-file errors. `DocumentService` validates and stores files; Views
only display state and forward actions. JPEG decode runs in an isolate using
`image`; dimensions are capped at 20 million pixels. PDFium via `pdfrx` opens and
renders a small first-page preview; encrypted, empty, or corrupt PDFs are rejected.
Picker read errors do not prevent other selected files from uploading.

Allow `.jpg`, `.jpeg`, and `.pdf` only, with matching content and at most 716,800
bytes. The original bytes are retained. File previews use `Image.memory` and
`PdfViewer.data`; engine initialization happens in `main`. No public URLs or
Firebase Storage dependency are introduced. Firestore quotas still bound usage.

`uploadedDocuments/{id}` stores exactly: userId, name, mimeType, fileBytes (Blob),
byteSize, createdAt (server timestamp), status, signatureId, signedAt, and
firstApplicationId. New files have status `unsigned` and three null binding/link
fields. Models receive ordinary Uint8List data; only Services handle Blob conversion.
One record per file stays below Firestore's 1 MiB limit. `firestore.indexes.json`
excludes fileBytes from indexing. Listing reads the owner's records and sorts them
locally. Payloads and original metadata cannot be updated by clients.

Uploads use a transaction with the selected stable ID. Retrying a matching
existing record succeeds without overwriting metadata; a mismatching existing ID
is rejected. Acknowledged uploads and per-file failures are shown separately.
Transactions require connectivity and have a 20-second deadline. Local pending
writes are excluded from the displayed saved list. No success is inferred merely
from a local cache write.

## Applications and removal (15.3–15.4)

`RentalApplication.documentIds` defaults to an empty list for older records.
`ApplicationService.submit` accepts up to five unique optional IDs and an optional
stable submission ID. It reads the selected files, validates ownership, creates
the application, and sets each file's firstApplicationId if not already set, all
in one transaction. Subsequent applications reuse that first-use marker. The
application ID is retained for uncertain confirmation retries on the same form.
Edits cannot change documentIds or remove the first-use marker. Unsigned files
may be attached. Deleted/missing or other-account files abort the whole operation.

Deletion is a transaction that permits only the verified owner of an unsigned,
never-linked record. Rules independently enforce that restriction, immutability,
schema/byte limits, server timestamps, and atomic application linking using
getAfter. The first-use marker prevents deletion races and remains permanent even
when an application is withdrawn. Attachment viewers remain owner-only; no new
advertiser document access is introduced.

The old staff-assigned text-document flow and its duplicated signed snapshots
are removed as the upload library replaces that entry point. Old Firestore
collections are not deleted or migrated; with no new rules matches they remain
denied by default. Existing favourites/messages/applications/maintenance rules
are preserved. Dependent US-11 adds reusable signatures and binding transitions.

## Validation and release

Run `flutter analyze` and `flutter test`. Tests use fake_cloud_firestore for file
persistence, actual JPEG/PDF validation, partial failure, retry idempotency, size
boundaries, account separation, reuse, deletion protection, and application linking.
Widget tests cover empty/upload/result states, JPEG/PDF viewer construction, and
removal confirmation at phone/tablet widths.

Actual security tests run against the official local Firestore emulator only:

```powershell
java '-Djdk.net.unixdomain.tmpdir=C:/Projects/MobileDev/apartment-app/.dart_tool/jtmp' -jar <emulator.jar> --host 127.0.0.1 --port 8187 --project_id demo-homeflow-us15 --single_project_mode true --rules firestore.rules
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8187'
node --test test/firestore/us15_rules_test.mjs
```

Create the temporary socket directory first. Its short path avoids the Windows
Java Unix-domain socket error encountered in the earlier implementation. Rules
tests cover valid/private access, limits, immutable bytes, owner-filtered queries,
atomic first-use marking, five-file reuse, legacy applications, and default deny.
Rules enforce bytes/type metadata limits; binary content decoding is app validation.

Definition of Done includes these user/technical guides, local story commit,
automated checks, Android execution, independent team review, and acceptance
criteria. Team review and PO acceptance are separate from self-testing. No new
push, PR, rules/index deployment, or merge into develop is authorized here.
Both stories use isolated local branches; shared Firebase data remains untouched.
