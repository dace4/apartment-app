> **Superseded (US 10 fix):** Apply immediately no longer reserves the apartment.
> It now only submits an application marked `immediate`. See
> `docs/US-10-technical-guide.md`. This plan is kept for history.

# Apply Immediately — no-Blaze implementation plan

## Goal

Allow a verified renter to reserve an Available apartment immediately without
Firebase Cloud Functions, Cloud Scheduler, or a Blaze billing account.

The existing normal application flow remains unchanged: renters can edit or
withdraw a normal application for five days. Nothing happens automatically when
those five days end. A renter may instead choose Apply immediately while their
own normal application is still open and within the five-day window.

## Confirmed behavior

- Reuse the current application form and its required fields: full name, phone,
  move-in date, and occupants; message remains optional.
- Show **Apply immediately** below **Apply** in `ApartmentDetailView`. It is
  visible and disabled unless the apartment is Available, matching Apply.
- That entry point creates a new immediate application and reserves the
  apartment in one Firestore batch.
- Show **Apply immediately** in `ApplicationDetailView` only when the current
  user's normal application is open, not withdrawn, the apartment is Available,
  and its five-day edit/withdraw window has not expired. It promotes the saved
  application to a reservation using its existing details.
- The winning application becomes `reserved` and can never be edited or
  withdrawn.
- Existing applications from other renters remain submitted/under review; no
  other renter's application is changed by the winning reservation.
- When a renter opens My Applications, their own open application for an
  apartment reserved by a different application is automatically withdrawn.
- A reservation shows a snackbar confirmation and redirects to My Applications.
- There is no automatic reservation at the five-day deadline. Once the window
  ends, normal applications simply remain locked as they do today.

## Secure Firestore design

Use a client-side Firestore `WriteBatch` for the immediate reservation. A batch
is atomic: it either creates/promotes the application and reserves the
apartment together, or makes no change.

The client must never have broad permission to set apartment availability. Add
strict Firestore rules that allow only this exact coupled transition:

1. The apartment is currently `available`.
2. The batch changes only its availability to `reserved` and writes a
   `reservationApplicationId` reference.
3. The referenced application exists after the batch (`getAfter`), belongs to
   the authenticated user, references the same apartment, and has
   `status: 'reserved'`.
4. A newly created immediate application has the complete validated schema,
   `applicationType: 'immediate'`, and server timestamps.
5. A promoted normal application already belongs to the user, remains within
   the five-day window, and changes only `status`, `updatedAt`, and its
   reservation marker/type fields allowed by the rules.
6. No client can reserve an apartment without simultaneously creating or
   promoting their own valid application.

Firestore rules recheck apartment availability when the batch commits. If
another renter reserved it first, Firestore rejects the batch and the app shows
a safe availability error.

## Data-model changes

- Add `reserved` to `ApplicationStatus`, with label `Reserved`.
- Add immutable `applicationType: 'normal' | 'immediate'` to applications.
- Add `reservationApplicationId` to an apartment only when it becomes
  Reserved. This is the rule-verifiable link between the apartment and winning
  application.
- Normal submissions write `applicationType: 'normal'`.
- Immediate creations write `applicationType: 'immediate'` and `status:
  'reserved'` in the same batch that reserves the apartment.
- `canChange(now)` returns false for every reserved/immediate application.

## Implementation steps and small commits

### 1. Application model and normal-flow schema

- Add `ApplicationStatus.reserved` and application type parsing/storage.
- Update status chips, application-detail copy, and `canChange`.
- Make normal submissions store `applicationType: 'normal'`.
- Extend rules to require that field and prevent ordinary client updates from
  setting an application to Reserved.
- Add model/view-model tests for eligibility and status presentation.

Suggested commit:

```text
feat(<US-ID>): add reserved application status
```

### 2. Atomic reservation service and Firestore rules

- Add one `ApplicationService` operation for creating an immediate reservation
  batch and one for promoting an existing normal application.
- In each operation, write the winning application and the
  `reservationApplicationId`/Reserved apartment update in one batch; rules
  enforce that the apartment is still Available when it commits.
- Add only the narrow Firestore rule transitions described above; retain the
  verified-email gate and existing owner-only application access.
- Cover successful creation, promotion, already-reserved failure, and invalid
  direct writes with Emulator Suite rule tests.

Suggested commit:

```text
feat(<US-ID>): reserve apartments with validated batches
```

### 3. Reuse ApplyView for immediate creation

- Add immediate-submit state/action to `ApplyViewModel` and reuse
  `ApplicationForm` with an Immediate Apply label.
- Add **Apply immediately** below **Apply** in `ApartmentDetailView`.
- Keep both buttons visible but disable them consistently for non-Available
  apartments.
- On success, show a reservation snackbar and go to My Applications; on a
  failed availability check, show the race-safe error.

Suggested commit:

```text
feat(<US-ID>): add immediate application form action
```

### 4. Promote an existing normal application

- Add the conditional action to `ApplicationDetailView`.
- Reuse saved application details; no duplicate form or route is needed.
- Hide/disable the action once withdrawn, past the five-day window, or once the
  apartment is not Available.
- Add tests for every eligibility condition and for the successful promotion.

Suggested commit:

```text
feat(<US-ID>): reserve from open application details
```

### 5. Verification and documentation

- Add service, rules, view-model, and widget tests.
- Run `flutter analyze`, `flutter test`, and Firebase Emulator Suite tests.
- Manually test both reservation entry points, simultaneous reservation
  attempts, disabled states, ordinary five-day expiration, and account
  isolation.
- Update user and technical guides to state that normal applications do not
  reserve automatically after five days.

## Acceptance criteria

- Immediate Apply creates or promotes only the active renter's application and
  atomically reserves an Available apartment.
- The first competing reservation wins; subsequent attempts fail safely.
- Reserved/immediate applications cannot be edited or withdrawn.
- A reservation does not immediately modify other renters' applications.
- A renter's own open application is withdrawn when they open My Applications
  and a different application has reserved that apartment.
- Normal applications are not automatically reserved at the five-day deadline.
- Direct Firestore writes cannot reserve an apartment without a valid linked
  application in the same batch.
- No Cloud Functions, Cloud Scheduler, or Blaze billing plan is required.
