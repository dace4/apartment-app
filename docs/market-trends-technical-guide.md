# Market Trends technical guide

Unnumbered addition assigned by the user. Follow ARCHITECTURE.md.
Model -> Service -> screen-specific ChangeNotifier -> View.
The service reads `marketTrends` from Firestore using `Source.server`; no local runtime catalogue,
fallback or automatic seeding exists. Selection and calculations belong in the ViewModel.
The View owns and disposes its ViewModel unless injected by a test. Late reads ignore completion after disposal.

## Firebase schema and access

`city` (string), `month` (ISO-8601 first-of-month string), `pricePerSquareMetre` (positive integer CHF/m²). Use one record per city/month. The ViewModel sorts months and compares the earliest and latest values; a missing or zero baseline has no percentage.
These are demo records. The screen explicitly discloses fictional content.
Reads require a verified account with `buyer` role. Client create/update/delete are denied.
Trusted Firebase operators maintain records. Existing routes/access gates are unchanged; no composite index is needed.

## Rollout after approval

1. Review this feature's rules addition against the current integration baseline. Do not deploy an older branch's whole rules file over newer rules.
2. Deploy the reviewed rules to the intended project only after approval.
3. Preview the seed: `node test/firestore/market_trends_seed.mjs --project=homeflow-a106f`.
4. Obtain a short-lived operator OAuth token outside the repository. Set `FIRESTORE_ACCESS_TOKEN` in the shell and repeat with `--apply` only after approval. Remove the token after use; never commit it or print it in logs.
5. Verify the screen with the correct role. Until rules deployment and seeding, permission errors or empty results are expected.

The JSON under `test/fixtures/` is operator seed input, never read by the app.
Seeds use one atomic create-only commit: if any ID exists, the commit fails without overwriting data.
For local tests set `FIRESTORE_EMULATOR_HOST=127.0.0.1:PORT` and run
`node --test test/firestore/market_trends_rules_test.mjs` with this branch's rules loaded.
To seed a local emulator, use `--project=demo-service-market-trends --apply`.

## Validation

Run `flutter analyze`, `flutter test`, and Android `flutter run`.
Record automated checks, Android execution, review and PO acceptance separately in
`docs/market-trends-validation.md`. No backlog story number was invented.
