# US-07: access implementation and context

## Architecture and interfaces

Keep MVVM: Services own Firebase I/O; ViewModels decide access; Views display
allowed actions and navigate. AuthViewModel.canAccess/redirectFor centralize route
policy, while canManage combines roles with a property relationship. Protected screen
ViewModels take a live canAccess callback and fail closed when it is absent or false.
Immediate-application ViewModels also take canApplyImmediately. These callbacks are
supplied by the router-created Views using the shared AuthViewModel.

AppUser adds role/ready getters. AuthService.userChanges combines Auth and profile
snapshots; loadUser performs a fresh one-shot profile read. Services do not cache auth
state. The app recreates its route shell and screen/shared ViewModels when UID,
verification, profile status, or saved roles change, disposing private subscriptions
and selections. Late screen notifications are guarded after disposal.

## Trusted property assignment

In Firebase Console, set apartments/{id}.ownerId to the owning Auth UID and
managerIds to an array of assigned Auth UIDs. Leave either absent when unknown.
Never derive ownership from advertiserContacts or a user's selected role. The client
cannot create/delete listings or change assignments. Listing creation and assignment
screens belong to future stories, which must extend these rules explicitly.

Maintenance reads and writes require the correct role + property assignment + the
existing request userId restriction. Services query owned/assigned apartments, merge
results, then query the creator's requests with apartmentId IN chunks of five. This
lets rules prove assignment, bounds rule document access calls, and supports more
than one query's property limit without dropping properties. A composite maintenance
index is supplied. Live property/role changes restart queries and clear old results.

## Local validation

See US-07-validation.md for exact outcomes, local emulator commands and outstanding
acceptance. Rules/indexes have not been deployed. Existing accounts require no bulk
migration: each completes role selection after verifying. Legacy properties remain
browseable but grant no maintenance access until an administrator assigns them.

## Files used for context

- AGENTS.md: story identity, isolation, verified-email preservation, guides and DoD.
- ARCHITECTURE.md: MVVM responsibilities and shared state ownership.
- DATA_MODEL.md and README.md: current collections and integration conventions.
- output/sprint-3-planning/ProductBacklog_FIG_2026_Apartment_S3_7days.xlsx in the
  original checkout: all 12 sheets read, including User Roles, Sprint 3, backlog and
  Done Definition. The supplied four fixes are Sprint 3 rows 12-15; owners/dates are
  unassigned. Shared freshness was not verified; this is the agreed local baseline.
- lib/models/app_user.dart and apartment.dart: existing account/property fields.
- lib/services/auth_service.dart and maintenance_service.dart: authentication,
  verification-token refresh, and maintenance persistence/query behavior.
- lib/view_models/auth_view_model.dart, register_view_model.dart,
  maintenance_booking_view_model.dart, maintenance_reminders_view_model.dart,
  favourites_view_model.dart and saved_searches_view_model.dart: state and listeners.
- lib/app.dart, lib/router/app_router.dart and app_routes.dart: shared ViewModels,
  routes, verified-email redirects, retained navigation branches.
- lib/views/auth/register_view.dart and verify_email_view.dart,
  lib/views/profile/profile_view.dart, lib/views/services/services_view.dart,
  lib/views/shared/widgets/scaffold_with_nav_bar.dart, apartment list/detail/card
  and protected screen Views: current inputs, actions and navigation.
- firestore.rules, firestore.indexes.json, firebase.json and pubspec.yaml:
  security boundaries, index definitions, emulator configuration and dependencies.
- Existing test/us11*, test/us15*, test/us18_notifications_test.dart,
  test/us23_new_offer_alerts_test.dart and test/firestore/*.mjs: test seams and
  regression behavior. Consumer test fixtures now explicitly grant the tested role.
- Original staged docs/user-guide/getting-started.md and verification.md: existing
  user-guide conventions and recorded acceptance limits; left untouched.

The two story branches are local and dependent: review US-06 first, then update
US-07 from develop after US-06 is integrated. No shared branch has been modified.
