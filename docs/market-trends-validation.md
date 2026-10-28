# Market trends validation

28 October 2026: revised at the user's request to use actual apartments in the app.
Base remains local `develop` at `2536539`; no push or merge is authorized.

Firebase read-only inspection found 18 apartment records with current price, surface, city, listing type and availability.
No price-history field was present. The screen therefore shows current asking-price statistics rather than fabricated historical change.
It uses the existing apartment stream and existing access rules; it does not require a new deployment.

- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: all 129 tests passed, including existing verified-email/access tests.
- Revised market tests cover live changes/removals, city reset, sale/availability selection, invalid price/surface data, exact averages, loading/error/retry and subscription disposal.
- Widget tests verify actual listing-detail navigation and 360/800 logical-pixel layouts with 1.5x text. A temporary readable-font capture at 390x844 was visually inspected; no layout issue was found.
- Remote cleanup: backed up and removed only the 18 exact demo `marketTrends` records previously seeded. All 18 were read first and compared field-by-field; deletion used update-time preconditions. Subsequent reads confirmed all 18 were absent. No apartment or contractor record was changed.
- No new Firebase rules deployment is required: the feature now uses the existing `apartments` read policy. The unused legacy catalogue read rule is no longer included in this branch's source.
The earlier Android run was blocked by Java's `Unable to establish loopback connection` error before Gradle compilation.
No Android acceptance pass, peer review, integration or PO acceptance is claimed.

Services wording follow-up: removed the Services coming-soon heading using the same option already present on main. Analysis passed with no issues and all 129 Flutter tests passed. No Firebase change was needed.
