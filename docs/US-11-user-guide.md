# US-11 — Use e-signatures: user guide

US-11 lets a user review a staff-assigned document, draw a signature, consent to
electronic signing, and reopen the saved signed record.

1. Log in with a verified email address.
2. Open **Profile → My documents**. Only documents assigned to your account appear.
3. Select a document marked **Awaiting signature**. Read the full text and check
   the title and version.
4. Check **I have reviewed the full document above**, enter your full name, and
   draw your signature in the box with your finger, stylus, or mouse.
5. Use **Clear signature** to start over. A dot or an empty drawing cannot be used.
6. Read and check the electronic-signing consent. Select **Sign and save**.
7. Wait for **Signed and saved**. It shows the original text, signature, signer,
   signing time, consent, and record ID. **Record details** shows integrity hashes.
8. Reopen the same document from **My documents** to view the saved record. Signed
   records cannot be edited, deleted, or signed again through the app.

Signing requires an internet connection. A failed save leaves your inputs on the
screen. Retry to confirm the result; if the first attempt saved, the retry opens
that same record. Leaving the screen while saving does not cancel a submitted
signature. Reopen the document to check its result.

If a document changed or was withdrawn, use **Reload document**, review again,
and provide fresh consent and a new signature. Reloading clears unsaved inputs.
An unavailable document cannot be signed. An integrity-check error must be
reported to the sender; the app will not present that record as a valid signature.

This version handles full-text documents supplied by trusted staff. PDF uploads,
PDF exports, multiple signers, and certified signing providers are outside this
version. It captures an in-app electronic signature; it does not issue a digital
signing certificate.

## Acceptance walkthrough (US-11.1–11.4)

Use a test assignment prepared by staff and a verified test account:

- Review and sign: the exact document and signature remain visible after reopening.
- Consent: the save button stays disabled until review, name, drawing, and consent
  are complete. Clearing the drawing also clears consent.
- Failure: disconnect before saving; no success is shown. Restore the connection
  and retry without a duplicate record.
- Repeat: reopen a signed document; there are no signing controls and its audit
  details remain unchanged.
- Integrity: have staff withdraw or revise an unsigned assignment after you review
  it; saving is rejected and you must reload. Use a new assignment ID for revisions.
- Access: signed-out, unverified, and other users cannot read your documents.

Android execution, team review, security-rule emulator validation, and Product
Owner acceptance must be recorded separately from automated Flutter tests.
