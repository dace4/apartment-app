# US-06: role profiles

`users/{Firebase Auth uid}` contains only `roles`, a nonempty unique list of
buyer/renter/homeowner/propertyManager. Users can get and replace their own profile,
including before email verification; all other application data stays verified-only.
Invalid/missing profiles require selection. Read failures fail closed with Retry.
AuthService combines Auth and profile streams, cancelling old profile listeners on
account changes. AuthViewModel holds state and drafts; Views display checkboxes.
Registration creates Auth once, sends verification, then saves roles. Partial failure
recovers through verification and legacy onboarding. No bulk account migration is needed.

Local checks and acceptance results are recorded in the US-07 validation guide.
