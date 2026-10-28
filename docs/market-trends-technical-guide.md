# Market trends technical guide

Unnumbered addition assigned by the user. Follow ARCHITECTURE.md.

Reuse `Apartment` and `ApartmentService.watchApartments()`; there is no separate market-data service or collection.
`MarketTrendsViewModel` subscribes to Firebase listings, owns city selection and computes current asking-price statistics.
It cancels its subscription on retry and disposal. The View renders the state and opens the existing apartment detail route.
Routing, role restrictions, and the verified-email gate are unchanged. No dependency, index, or new Firebase rule is required.

Include sale listings with availability Available or Reserved, price > 0, surface > 0 and a nonblank city.
Use the stored city labels as they appear in Home. Do not merge or invent locations.
Average price is sum(price)/count. Average price per m² is sum(price/surface)/count, with equal weight per listing.
Round final displayed averages to whole CHF; minimum and maximum are the actual asking prices.
Do not round individual price/m² values before averaging.

Creation dates are not historical price observations. The app has no recorded price history, so it shows a current overview
and explicitly says changes over time are unavailable. Do not infer historical movements from listing creation dates.
The former invented catalogue model, fixture, seed script and dedicated read rule have been retired.
Only the 18 exact synthetic documents previously uploaded are eligible for remote cleanup; no apartment or contractor records are changed.

Run `flutter analyze` and `flutter test`. Tests cover live changes, filtering, precise averages, invalid data,
empty/error/retry states, subscription disposal, actual detail navigation and enlarged text layouts.
Record Android execution, team review and PO acceptance separately from automated results.
