# US-11 — Use e-signatures: technical guide

## Requirements and implementation

Source requirements are the supplied US-11 story, tasks 11.1–11.4, and Definition
of Done: user guide, technical guide, code committed to Git, completed code
review, and passed acceptance criteria. No sprint workbook was supplied. No
external backlog status or ownership has been changed.

The branch is `feature/US-11-e-signatures`, based on local `develop` at `80d889b`.
Remote freshness is unverified. Work is isolated in `.worktrees/us-11` so the
original checkout and unrelated generated files remain untouched. No push, PR,
merge, live data provisioning, or Firebase deployment is part of this session.

Architecture follows `ARCHITECTURE.md`: pure data models (Firestore Timestamp
conversion only), one DocumentService for Firebase access, screen-specific
ChangeNotifier ViewModels, and Material Views forwarding actions. Shared pure
hashing helpers are in `utils/`. Navigation is confined to Views/router and
inherits the existing US-06/07 verified-email gate. Existing US-08/12/16 rules
remain in place; only US-11 matches were added.

## US-11.1 workflow and states

Staff issue a full-text document to one user. Persisted assignment states are
`ready` and `withdrawn`; unknown or malformed states cannot be signed. A separate
signed record means the assignment is **Signed**. Local review/consent/capture
and **Saving** are transient screen states, not staff-controlled document states.
Failures retain inputs and show an action error. Reload discards inputs and
requires renewed review and consent. The review screen shows **Signed and saved**
only after a server read confirms a valid saved record. The list's **Signed** badge
uses signed-record IDs from Firestore snapshots; record integrity is checked when
the record is opened.

There is one signer and one immutable signed record per assignment. Revised
terms require a new assignment ID and a new signature. Staff must retain issued
assignments, especially after signing; signed records can still be opened by ID
if an administrator removes an assignment, but the assignment list then loses
that entry. User-facing document creation/assignment and PDF processing are not
part of US-11.

## US-11.3 storage and audit

`signingDocuments/{documentId}` is provisioned only through a trusted Firebase
Console/Admin SDK procedure. Use exactly these fields:

| Field | Type | Requirement |
| --- | --- | --- |
| userId | string | Existing Firebase Auth UID of the intended signer |
| title | string | Nonblank, at most 200 characters |
| body | string | Complete text, nonblank, at most 100,000 characters |
| version | integer | Positive document version |
| issuedAt | Firestore timestamp | Issuance time; nanoseconds are preserved |
| state | string | `ready`, or `withdrawn` to stop unsigned signing |

Clients cannot create, modify, or delete assignments. Do not assign the same ID
to another user or replace its terms. To revise, withdraw the unsigned old
assignment and create a new ID. Do not delete signed records using admin tools.
Admin SDK privileges bypass client security rules, so trusted-admin operational
controls remain necessary. No admin UI or credentials are included in the app.

`signedDocuments/{documentId}` contains the exact original `document` map,
signerId, signerEmail, signerName, signature, documentHash, recordHash,
consentVersion, consentText, consented=true, and signedAt. The UID and email come
from Firebase Auth; name is the user's declaration. The drawing is normalized
vector strokes encoded as JSON, with at most 2,000 points / 100,000 encoded
characters. A blank or stationary-dot drawing is rejected by app validation.
Consent version `US-11-v1` and the exact displayed wording are retained. No IP,
device identifier, private signing key, or public file URL is collected.

DocumentService uses a Firestore transaction to read the deterministic signed
record ID, then compare the current source to the reviewed fingerprint. It
creates the signed record only if ownership, state, and content still match.
Concurrent attempts and uncertain retries use the same ID and never overwrite
the first record. Transaction retries cannot substitute changed content. Saving
uses a server timestamp; follow-up reads use Source.server. A failed confirmation
does not produce success; retry can recover the already committed record.

Rules enforce verified identity, assigned ownership, exact original snapshot,
fixed consent, server time, field schema/limits, and create-only signed records.
Unfiltered document/record queries are denied; queries constrain userId/signerId.
Rules do not parse stroke JSON or compute SHA-256: geometry and digest checks
are client validation. Hashes are integrity checks, not certificates or proofs
that trusted administrators or a modified client cannot forge data. Rules enforce
snapshot equality independently of client hashes.

Document fingerprint is SHA-256 of UTF-8 JSON of this fixed ordered array:
`['US-11-document-v1', id, userId, title, body, version, issuedAtSeconds,
issuedAtNanoseconds, state]`. No whitespace/newline normalization occurs.
Record fingerprint uses `['US-11-record-v1', documentHash, signerId, signerEmail,
signerName, signatureJson, consentVersion, consentText]`. signedAt is not hashed:
it is supplied by Firestore and protected against client changes by rules.
Read-time validation detects corrupted content, signatures, consent, or identity.
The app does not claim certificate-based digital-signature or jurisdictional
legal assurance.

Before use with live assignments, a separately authorized release must deploy
the reviewed rules. Without those matches, production's existing default-deny
rules will reject US-11 access. No configuration files or credentials changed.

## US-11.4 verification and Definition of Done

Run from the US-11 worktree:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

Unit/service/ViewModel tests use fake_cloud_firestore without production data.
Widget tests exercise real pointer capture, review/consent enablement, signing,
saved-record rendering, phone/tablet widths, and doubled text size. Optional
readable layout captures can be generated with:

```powershell
flutter test test/us11_document_widgets_test.dart --dart-define=US11_CAPTURE=true --dart-define=US11_FONT_DIR=C:/Projects/Flutter/flutter/bin/cache/artifacts/material_fonts
```

These images are preliminary widget-test renders, not Android execution evidence.
Native visual review additionally requires installed-device screenshots and
checks of Back gestures, keyboard/system insets, and system font scaling.

Actual rules tests use the official Firestore emulator, local-only host checks,
demo project `demo-homeflow-us11`, Node built-ins, and no npm dependencies:

```powershell
# Terminal 1: use the locally installed emulator JAR and a supported Java runtime.
java -jar <path-to-cloud-firestore-emulator.jar> --host 127.0.0.1 --port 8187 --project_id demo-homeflow-us11 --single_project_mode true --rules firestore.rules
# Terminal 2:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8187'
node --test test/firestore/us11_rules_test.mjs
```

The rule suite checks valid binding/server time, unauthenticated/unverified/other
users, assignment protection, consent/schema/identity limits, altered snapshots,
withdrawal, repeat writes/deletion, owner queries, and default-deny preservation.
Fake Firestore tests do not verify security rules. Rules-emulator and Android
startup attempts on this host currently fail before app/rule execution with
Java's `Unable to establish loopback connection` / `Invalid argument: connect`.
Those checks remain pending; do not mark them passed from test doubles.

Automated acceptance evidence covers tasks 11.1–11.4. Human Android acceptance,
an independent team member pulling/running the branch, reviewed integration into
develop, and PO acceptance remain separate outstanding checks. The supplied
Definition of Done cannot be claimed complete until those applicable checks pass.

Local validation on 13 October 2026:

| Check | Result |
| --- | --- |
| User and technical guides | Provided with US-11 |
| Flutter tests | 19 passed |
| Flutter analysis | No issues found |
| Rules test JavaScript syntax | Passed `node --check` |
| Actual rules suite | Blocked: emulator startup fails; runner reports local connection refused |
| Android startup | Blocked: Gradle fails with the Java loopback error |
| Layout captures | Phone/tablet widget renders, including doubled text; preliminary only |
| Local Git commit | Implementation, tests, and guides committed on the story branch; see `git log -1` |
| Native visual review | Pending device captures (reviewer disposition: recapture) |
| Team code review and PO acceptance | Pending |
| Integration/deployment | Not performed |

Technical references: [Firebase transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
and [security-rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions).
