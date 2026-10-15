# US-11 â€” Reusable signature and binding: technical guide

This replaces the earlier per-document text/signature/snapshot workflow, following
the revised story and approved plan. No legacy records require a viewer. Existing
Firebase collections are left untouched. US-15 supplies uploads and immutable
file storage; its local prerequisite commit is `4b30b8a`.

## Structure and state

The feature follows `ARCHITECTURE.md`: UserSignature is a data model,
SignatureService accesses Firebase, SignatureViewModel owns drawing/loading/save
state, and SignatureView displays it. SignatureDrawing/SignaturePoint and the
existing signature pad are reused; the pad now lives under views/signatures/widgets.
DocumentService adds a single bindSignature operation; the document review
ViewModel owns availability and action state. The router and Profile expose
**My Signature**, preserving the existing verified-email redirect and other stories.

## Persistence and audit (11.1â€“11.3)

`userSignatures/{uid}` stores exactly drawing (normalized stroke JSON, at most
2,000 points / 100,000 characters) and updatedAt (server timestamp). Blank or dot
drawings are rejected. Save/replace writes the same UID-based ID; no extra ID,
signature revision, file rendering, or signing-provider infrastructure is needed.
The service uses a transaction and a server read to confirm save success. An
unreadable drawing is treated as unavailable and can be replaced through the UI.
Rules restrict get/create/update to the verified account; listing/deletion is denied.

The uploaded document has two states: `unsigned` and `signed`. Initial signatureId
and signedAt are null. Binding reads the file and the owner's current signature
in a transaction, validates ownership and signature readability, then updates
only status=`signed`, signatureId=uid, and signedAt=server timestamp. It reads back
the saved file before displaying success. A retry of an already signed file
returns the original binding; it never replaces the signing time or file bytes.

The View asks explicit confirmation naming the file before calling bind. The
minimal audit record is the existing owner UID, signature ID, and server signing
timestamp. Signed status denotes the confirmed association; no historical drawing,
consent-version record, duplicated document snapshot, or digest is stored. This
is the chosen simple ID binding, not certificate-based cryptographic signing.
Changing the user's current drawing leaves earlier bindings unchanged.

Rules enforce an existing signature ID belonging to the signer, server time,
the one-way unsignedâ†’signed transition, immutable file bytes/metadata, and blocked
deletion of signed files. Signature geometry is validated in the app; rules
bound the JSON string size. Trusted Admin SDK/console operations bypass rules.
US-15 application linking remains allowed after signing and preserves the binding.

## Testing and local use (11.4)

Run `flutter analyze` and `flutter test` from the combined US-11 worktree.
The combined suite covers signature creation/replacement with the same ID,
blank/dot rejection, missing/unreadable signatures, draft preservation after
failure, binding confirmation cancellation/success, repeat binding, interrupted
confirmation retries, original byte preservation, and the US-15 upload/application
cases. Widget tests draw through the actual pad at phone/tablet widths and verify
that binding controls disappear after signing.

Run both real security suites against an official local Firestore emulator:

```powershell
# First create .dart_tool/jtmp at the original repository root.
java '-Djdk.net.unixdomain.tmpdir=C:/Projects/MobileDev/apartment-app/.dart_tool/jtmp' -jar <emulator.jar> --host 127.0.0.1 --port 8188 --websocket_port 5873 --project_id demo-homeflow-us11 --single_project_mode true --rules firestore.rules
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8188'
$env:US_DOCUMENTS_DEMO_PROJECT='demo-homeflow-us11'
node --test test/firestore/us15_rules_test.mjs test/firestore/us11_rules_test.mjs
```

These tests exercise signature privacy/replacement, missing signatures, immutable
bindings and original bytes, timestamps, application linking/reuse, and the
preserved default-deny protections. The short socket directory fixes this host's
previous Java loopback error; it is a per-process option, not a machine change.

For a local Android UI trial, `.dart_tool/us11_demo.dart` in the implementation
worktree seeds JPEG/PDF fixtures into fake_cloud_firestore and exposes the actual
signature, library, and file-review Views. It never connects to shared Firebase:

```powershell
$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:/Projects/MobileDev/apartment-app/.dart_tool/jtmp'
flutter run -d emulator-5554 -t .dart_tool/us11_demo.dart
```

This ignored demo is a local validation aid, not the production entry point.
Native startup, UI checks, and rule tests must be reported separately from unit
tests. Shared Firebase use still requires separately authorized deployment of
the reviewed rules and US-15 index exemption. No push, PR, deployment, or merge
into develop is authorized by this implementation task.

Both stories require user/technical guides, committed code, independent team code
review, and passed acceptance criteria. Automated tests and agent inspection do
not constitute team review or PO acceptance.

Local verification on 15 October 2026: 27 combined Flutter tests pass, analysis is
clean, and all 12 tests reported by the combined real-emulator rule suites pass.
The debug APK builds and installs on Android 16 (emulator-5554). The local-data
demo exercises actual drawing/save, PDF rendering, confirmation/binding, missing
signature protection, and a PDF selected through Android's native picker. Native
captures are retained under `.dart_tool/us11-review/`. Initial `flutter run
--no-resident` lost its DevFS connection after installation; the installed demo
continued running and was inspected directly. No shared Firebase writes occurred.

The review layout also passes a 640×320 widget regression with a 200-character
filename and 1.3× text. A rebuilt APK was inspected at 800×400 logical pixels
with enlarged text: filename truncation, scrolling to both actions, and full
confirmation content/actions remain accessible. `flutter build apk --debug`
completed successfully; Flutter service attachment remains a host limitation.
