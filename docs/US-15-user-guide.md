# US-15 — Upload application documents

Open **Profile → My documents → Upload documents**. Choose up to ten `.jpg`,
`.jpeg`, or `.pdf` files. Each file must be nonempty and no larger than **700 KiB**.
PDFs must be readable and unencrypted. JPEGs must decode and have no more than
20 million pixels, protecting the app against excessive decompression memory use.
The app does not resize or rewrite your originals.

Each selected file has its own result. Successful uploads remain saved when
another file fails. Use **Retry upload** after a connection error. Retrying uses
the same file ID, so an upload whose confirmation was interrupted is not duplicated.
Dismiss an invalid file and select a corrected file. Canceling the picker does
not upload anything. Your files are private to your verified account.

Tap a saved document to preview it. JPEGs support pinch-to-zoom; PDFs support
scrolling through pages. **Remove document** asks for confirmation and permanently
deletes only unsigned files that have never been attached to a submitted application.
Signed records and previously used attachments cannot be removed.

When applying for an apartment, select up to five optional documents from the
attachment list. Unsigned documents are allowed. The same upload can be reused
in another application. Existing applications need no attachments. Once submitted,
the attachment selection cannot be changed; other application edits retain their
existing five-day limits. Open an application and tap its attachment to view it.

The reusable **My Signature / Bind signature** workflow is provided by dependent
US-11. Binding does not print a drawing inside your file.

Staff must deploy the reviewed Firestore rules and binary-field index exemption
before this feature can use shared Firebase data. No Storage bucket is needed.
Firestore's free storage/read/write quotas still apply.
