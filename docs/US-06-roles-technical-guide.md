# US-06: role profiles

`users/{Firebase Auth uid}` contains `roles`, a nonempty unique list of
buyer/renter/homeowner/admin, and optionally `fullName` (1–100 characters, not blank)
and `phone` (`[+0-9 ()-]{6,20}`), with the same limits as an application.
`UserProfile` (models/user_profile.dart) maps the document; `UserProfileService`
writes it at registration (`createProfile`, one write) and merges later writes
(`saveRoles`, `saveContactDetails`) so neither erases the other. `AppUser.fullName`
and `phone` pre-fill `ApplicationForm` (`defaultFullName`/`defaultPhone`, ignored when
editing) and `InsuranceContactView`. Profile edits them with `ContactDetailsCard` and
`ContactDetailsViewModel`. A contact-only update never resets the role checkboxes
(`AuthViewModel._listen`), and is not part of app.dart's session key.
`hasRoles()` in the rules accepts the two optional keys; without that, a profile with a
name would fail `verified()`. `admin` is set in the Firebase console only: the rules
refuse it from the app, and an admin keeps it when saving. Users can get and replace their own profile,
including before email verification; all other application data stays verified-only.
Invalid/missing profiles require selection. Read failures fail closed with Retry.
AuthService combines Auth and profile streams, cancelling old profile listeners on
account changes. AuthViewModel holds state and drafts; Views display checkboxes.
Registration creates Auth once, sends verification, then saves roles, name and phone. Partial failure
recovers through verification and legacy onboarding. No bulk account migration is needed.

Local checks and acceptance results are recorded in the US-07 validation guide.
