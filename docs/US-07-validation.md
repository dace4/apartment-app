# US-06/07 validation — 18 October 2026

| Check | Outcome |
| --- | --- |
| Local implementation | Completed on isolated dependent story branches |
| flutter analyze --no-pub | Passed: no issues |
| flutter test --no-pub | Passed: 54 tests |
| Firestore emulator permission tests | Passed: 19 tests across US-06/07, US-11 and US-15 |
| Role form visual verification | Registration, role selection and Profile rendered at 400×900; inspected with readable fonts; no overflow |
| Small-screen Profile interaction | Widget test at 360×800 passed |
| UI skill mechanical check | No findings on the checked role/navigation surfaces |
| Android build/install/start | Passed on emulator-5554, Android 16/API 36, using flutter run --debug --no-resident |
| Manual Android role/assignment acceptance | Pending against a backend with these rules/indexes installed |
| Peer code review | Pending |
| Integration into develop | Not performed |
| Product Owner acceptance | Pending; not inferred from tests |
| Remote freshness | Not verified; started from local develop 68cc718 |
| Remote writes | None: no push, PR, deployment or shared-branch merge |

## Coverage

All 15 role combinations and union permissions; missing/empty/invalid roles;
profile persistence and fresh reads; registration forwarding; Profile edits and failed
save retry; signed-out/unverified/legacy routing; role removal on a protected deep
link; account-state changes; property role + UID checks; missing legacy assignments;
unauthorized file actions; profile and record isolation; forged property assignments;
maintenance creator restrictions, rescheduling, cancellation and assignment revocation;
renter-only reservation; existing document/signature/attachment protection regressions.

Fixtures in the older Firestore suites now include valid role profiles and the
already-required normal applicationType. Tests only contact a localhost demo project.

## Reproduce

Run flutter pub get, flutter analyze, and flutter test in the US-07 worktree.
Start the cached Firestore emulator with --host 127.0.0.1 --port 8796
--project_id demo-homeflow-us15 --rules firestore.rules. Set
FIRESTORE_EMULATOR_HOST=127.0.0.1:8796, then run:

    node --test --test-concurrency=1 test/firestore/us06_us07_rules_test.mjs test/firestore/us11_rules_test.mjs test/firestore/us15_rules_test.mjs

On this Windows machine Java's Unix-domain pipe initially failed. Setting
JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<nonexistent directory inside the worktree>
made Java fall back to TCP; the same setting allowed Gradle/Android startup.
No Java, Flutter, dependency, or machine settings were changed persistently.

## Manual acceptance still required

With a test backend configured for the new rules/index, register with multiple roles,
verify email, restart and check persistence. Log in with a legacy account and save
roles once. Edit roles in Profile; confirm unauthorized actions and tabs disappear
and direct links return home. Use two accounts to confirm record isolation.
Assign ownerId/managerIds in the test console; check maintenance choices and revoke
an assignment while its screen is open. Verify property access disappears, while
existing request creator restrictions remain. Test email resend and profile recovery
with simulated failures. Obtain peer review and record PO acceptance separately.

Implementation context and file inventory: US-07-access-technical-guide.md.
