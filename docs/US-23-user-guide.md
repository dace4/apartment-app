# US-23 — Receive alerts for new offers: user guide

US-23 lets you save a search and be alerted in the app when a new apartment
matching it appears.

## Save a search

1. Log in with a verified email address.
2. On the **Search** tab, open **Filters** and choose your criteria: location,
   rent or buy, price range, rooms, surface and amenities. Select **Apply filters**.
3. Tap the bookmark button (**Save this search**) at the top of the list. It is
   disabled while no filter is active, because such a search would match every
   offer.
4. Give the search a name (at most 40 characters) and select **Save**.

The apartments that already match when you save do not alert you: only offers
that appear afterwards do. You can save up to 5 searches.

## Manage your saved searches

Open **Profile → Saved searches**. For each search you can:

- switch **Alerts for new offers** off or on;
- select **Show results** to open the apartment list with its filters;
- select **Delete** to remove it. Alerts you already received stay in your
  notifications.

## Receive and open alerts

A new offer appears in **Profile → Notifications** as **New offer: …**, with the
search name, the city and the price. Tap it to open the apartment.

An apartment is a new offer for a search when it is **available**, meets every
criterion of the search, and was not already known by that search. Each offer
alerts at most once per search, even after restarting the app. A reserved
apartment that becomes available again alerts if it matches.

## Switching alerts off

Alerts appear only when both switches are on:

- the **Alerts for new offers** switch of the search;
- the **New listings** switch on the **Notifications** page (US-18). When it is
  off, **Saved searches** shows a reminder with a link to it.

Offers that appear while alerts are off are marked as seen: switching alerts
back on does not send a batch of old alerts.

## Limits

The app checks for new offers while you are logged in, whatever the open tab.
There are no push notifications: an offer published while the app is closed
alerts you the next time you open the app.

## Acceptance walkthrough (US-23.1–23.4)

Use a verified test account and add test apartments in the Firestore console
(`apartments` collection, `availability: "available"`):

- Matching: a new available apartment that meets the criteria creates one
  notification; one in another city or above the maximum price creates none.
- Opening: tapping the notification opens that apartment.
- Duplicates: restarting the app or refreshing the list creates no second
  notification for the same offer.
- Opt-out: with the search switch off, or US-18's **New listings** switch off,
  a matching offer creates no notification, and switching back on creates no
  alert for it.
- Limit: a 6th saved search is refused with a message.
- Accounts: another account sees neither your searches nor your alerts.
