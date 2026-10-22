# US-14 — Property FAQ: technical guide

## Requirements and implementation

Source: US-14 and its Sprint 3 tasks.

| Task | Implementation |
| --- | --- |
| 14.1 Prepare property-related questions and answers | 18 entries in `FaqService.entries`, grouped by `FaqCategory`, consistent with the implemented stories (US-05, 08, 09, 10, 12, 13, 15, 16, 17, 18, 20, 23, 24) |
| 14.2 Replace placeholder with accessible FAQ linked to property queries | `FaqView` replaces `PlaceholderView`; search field, topic chips, expandable answers with links; opened from apartments with a contact card |
| 14.3 Verify content, navigation and empty states | `test/us14_faq_test.dart` |

The branch is `feature/US-14-property-faq`. Architecture follows
`ARCHITECTURE.md`:

| Layer | Files |
| --- | --- |
| Model | `faq_entry.dart`: `FaqEntry` (with `matches(query)`) and `FaqCategory` |
| Service | `faq_service.dart`: fixed content, no Firebase, so it works offline |
| ViewModel | `faq_view_model.dart`: search, topic, empty message, allowed links |
| View | `profile/faq_view.dart` (owns its ViewModel) |
| Routes | `AppRoutes.faqForApartment(id)` = `/profile/faq?apartment=<id>`; button in `apartment_detail_view.dart` |

No Firestore collection or rule is added.

## Decisions

| Rule | Decision |
| --- | --- |
| Search | Case-insensitive, in questions and answers; empty search matches all |
| Topics | One topic at a time; selecting it again (or **All**) clears it |
| Links | Shown only if `AuthViewModel.canAccess(location)` is true, so the FAQ never offers a page the router would refuse |
| Property queries | With `?apartment=<id>`, a card links to `contactAdvertiser(id)` when the user may contact advertisers |
| Empty state | `MessageView` with *No questions match "…"* and **Show all questions** |
| Accessibility | Standard Material widgets with text labels: labelled search field, tooltip on the clear button, chips and expansion tiles readable by TalkBack |

## Tests

`flutter test test/us14_faq_test.dart` covers: unique ids and complete
entries, links pointing to existing routes, search in questions and answers,
topic selection and reset, empty state and clear, links hidden by roles, the
contact card, and the view's empty state and expansion.
