# US-11: Signed-document disclaimer (Sprint 3)

## User guide

Open **Profile → My documents**, select an unsigned file, and review it. Save a
drawing under **My Signature** first if prompted. Tap **Bind signature**, then
**Confirm and sign**. After the binding is confirmed, the document shows its
Signed status, signing time, and this red message:

> This signed document is certified and cannot be changed after it has been signed.

The message remains when you leave and reopen the signed document. Bind and
Remove document are unavailable for signed documents. Cancelling or a failed
binding does not show the message. If confirmation fails, reload the document
to check its saved status before retrying.

The message describes the app's existing signing protection. Binding associates
the saved signature identity with the original document; it does not modify the
PDF/JPEG, generate a digital certificate, or add an external certification service.

## Technical guide

- The two tasks are **US-11.S3.01** (red disclaimer) and **US-11.S3.02**
  (reopening and immutability verification).
- `DocumentReviewView` displays wrapping text with `TextStyle(color: Colors.red)`
  in its existing `document.isSigned` section, beneath the signed status/time.
- `DocumentReviewViewModel.bind()` receives a document only after
  `DocumentService.bindSignature()` completes its transaction and confirms the
  result with a server read. The view does not infer success from the tap or
  maintain a separate disclaimer flag. Reopening loads the persisted state.
- An unconfirmed commit leaves the disclaimer absent until a successful reload
  establishes that the document is signed.
- Models, public interfaces, schema, services, rules, role checks, and the
  verified-email gate are unchanged. Existing protections preserve original
  bytes, signature identity, and first signing time; signed files cannot be
  deleted or signed again. Existing application-attachment linking remains valid.

## Verification record — 20 October 2026

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed, **86 tests**.
- Focused US-11 tests: passed, **17 tests**, including four new widget tests.
  They verify exact wording/red styling after confirmation, fresh-screen
  reopening after signature replacement, hidden Bind/Remove controls,
  cancellation, pending and failed binding, and recovery from an unconfirmed
  commit. Portrait 360×640 and landscape 640×320 use 1.5× text scaling without
  layout exceptions. Existing service tests cover unchanged bytes, repeat
  binding, signing time, and deletion protection.
- Architecture check: this is a presentation change in the View; Firebase
  access remains in Services and action state remains in the ViewModel.
- Firestore permission tests: **not run**. The installed local emulator fails
  during Java selector initialization with `Unable to establish loopback
  connection` / `Invalid argument: connect` under Java 21, 23, and 26.
- Android execution/acceptance: **not completed**. Medium_Phone booted and was
  detected as emulator-5554, but `flutter run --no-pub -d emulator-5554` failed
  during Gradle assembly with `Unable to establish loopback connection`.
- Peer review, integration, and Product Owner acceptance: **pending**. No remote
  push, PR, deployment, or merge is part of this local change. The branch starts
  from local `develop`; freshness against the remote was not verified.

## Remaining acceptance checks

1. Start the local Firestore emulator with `firestore.rules` and demo project
   `demo-homeflow-us11`. Set `FIRESTORE_EMULATOR_HOST` to its localhost address,
   then run `node --test test/firestore/us11_rules_test.mjs`.
2. On Android, log in with a verified Buyer/Renter account, save a signature,
   open an unsigned document, and confirm signing. Check the exact red message,
   signed time, readable wrapping, and absent Bind/Remove controls.
3. Leave and reopen the file, then restart the app and reopen it again. Check
   that the message/time persist and original preview contents are unchanged.
4. Cancel signing another unsigned file; verify no disclaimer. Simulate a failed
   binding and verify no success message until a reload confirms persisted signing.
5. Complete a peer run/review and record PO acceptance separately.
