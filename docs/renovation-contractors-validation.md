# Renovation Contractors validation

Date: 28 October 2026. Base: local `develop` at `2536539`; remote freshness not verified.
The two feature branches remain separate and unmerged. Root working-tree changes were preserved.

- Initial full `flutter test --no-pub`: passed (126 tests), including US-06/07 auth and role checks.
- Final targeted feature tests: passed (9 tests), covering city selection, empty/error/retry, disposal, model/seed checks and enlarged text at 360/800 logical pixels.
- `flutter analyze --no-pub`: passed, no issues.
- Visual inspection: 390 x 844 logical pixels at text scale 1.5, readable fonts loaded in a temporary test-only capture harness; passed. Preview in `build/qa/contractors.png` (not a tracked deliverable).
- Seed dry run: passed; no production documents written.
- Node syntax checks for seed and rule tests: passed.
- Firestore rule execution: blocked. Installed Java runtimes fail to establish a loopback connection (`SocketException: Invalid argument: connect`) before emulator startup. Tests are supplied but not claimed to have run.
- Android `flutter run -d emulator-5554 --debug --no-pub --no-resident`: attempted; Gradle failed before compilation with `Unable to establish loopback connection`. No Android acceptance pass is claimed.
- Firebase rules deployment and initial remote data upload: pending approval. Until then the page may show an empty collection or access error.
- Peer review, integration and PO acceptance: outstanding.

Architecture review: data conversion stays in Models; Firebase access stays in Services;
ViewModels own state/filtering/calculations; Views render and navigate. Existing auth and router code is unchanged.
