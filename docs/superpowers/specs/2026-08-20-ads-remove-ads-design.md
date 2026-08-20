# Shardfall Ads Monetization and Remove Ads Design

**Date:** 2026-08-20  
**Status:** Awaiting user review  
**Scope:** Production-ready monetization configuration; rollout remains
Internal/Closed Testing until the owner approves Production

## Context

Shardfall already has a Google Play consumable purchase flow for `gold_500`.
The Flutter client delivers the Gold idempotently through `SaveService`, queues
receipts when Supabase is unavailable, and the `verify-purchase` Edge Function
checks the receipt with Google Play before writing the server ledger.

The app now needs two monetization surfaces:

1. AdMob banner advertising on non-gameplay screens.
2. A permanent Google Play non-consumable product, `remove_ads`, priced at
   US$4.99, which disables every ad for the player.

The implementation must preserve the existing Gold flow and must not show ads
during an active duel, story battle, Arena battle, or PvP battle.

## Goals

- Add a production-shaped AdMob integration that fails soft when an ad cannot
  load or the network is unavailable.
- Show a banner on the main menu, Collection, and Booster screens.
- Show an interstitial only after a completed local Duel, Story battle, or
  Arena run, after the result/reward flow is complete and before returning to
  the previous screen. PvP never triggers an interstitial.
- Add a polished Remove Ads entry point in Settings and a clear purchase state
  (`available`, `purchasing`, `pending`, `owned`, `error`).
- Verify `remove_ads` directly with Google Play and persist the entitlement in
  the server-authoritative purchase ledger.
- Restore the entitlement after reinstall or sign-in, and apply a refund or
  chargeback so ads can become active again.
- Keep the app usable offline. A Play purchase reported as completed can
  immediately suppress ads locally; backend verification is retried until it is
  durable. Server verification never trusts a client-supplied price.
- Configure the Play Console product and AdMob app/units for the eventual
  Production release, while keeping the new app build in Internal/Closed
  Testing for now.
- Ensure the Production release uses the same real AdMob IDs and product IDs,
  so ads can begin serving as soon as Google approves the app and the release
  is live; no code change or emergency console edit should be needed then.

## Non-goals

- No rewarded ads, offerwalls, subscriptions, or ad placement inside gameplay.
- No change to the Gold product, Gold amount, or existing PVP protocol.
- No server-side anti-cheat redesign for ordinary single-player save data.
- No Production release, staged rollout, or public listing publication by this
  task. Production-readiness is required, but publication remains an explicit
  owner decision.
- No attempt to use a client-provided price as proof of payment.

## Product and entitlement contract

The purchase catalog will contain:

| Product ID | Type | Price | Result |
| --- | --- | --- | --- |
| `gold_500` | consumable | existing Play price | grant 500 Gold once |
| `remove_ads` | non-consumable | US$4.99 | grant the `remove_ads` entitlement |

`remove_ads` is deliberately lowercase with an underscore so the same stable
identifier can be used in Flutter, Google Play, Supabase, and tests.

The client will use a separate `RemoveAdsPurchaseService` so the already-tested
consumable Gold state machine is not made more fragile by non-consumable
branching. Both services use the same catalog and the same backend verifier.
The service will:

- query `remove_ads` from Google Play;
- accept `purchased` and `restored` results only when the Play purchase object
  reports a usable purchase token;
- call `SaveService.grantRemoveAds` idempotently;
- complete the Play purchase when the platform requires completion;
- queue `remove_ads|purchaseToken` for retry when Supabase verification fails;
- call `restorePurchases` on initialization and when the user taps Restore;
- never remove the local entitlement because of a transient network failure.

The local entitlement is a boolean (`removeAds`) persisted in
`SharedPreferences` and included in the cloud snapshot. The purchase token and
order ID remain in the existing purchase identifier ledgers so a purchase is
not delivered twice across restore/retry paths. A refunded entitlement is
recorded in a revoked set and cannot be re-granted by a stale restore.

## Server verification and data model

The existing `public.purchases` table is the authority for paid entitlements.
A migration will extend it without rewriting existing Gold rows:

- add nullable `entitlement_id`;
- allow `gold_amount` to be null for an entitlement row;
- replace the current check with a mutually exclusive check:
  - Gold row: `gold_amount > 0` and no `entitlement_id`;
  - entitlement row: `gold_amount is null` and `entitlement_id = 'remove_ads'`;
- add an index for `(user_id, entitlement_id, state)`;
- add a security-invoker helper for the signed-in user's active
  `remove_ads` rows.

The global purchase-token unique constraint remains the idempotency boundary.
The Edge Function will use a catalog entry shaped like:

```text
gold_500   -> goldAmount 500, entitlement null
remove_ads -> goldAmount null, entitlement remove_ads
```

`verify-purchase` will reject every product outside that catalog, reject an
empty token, query the Google Play product purchase endpoint using the exact
product ID, require `purchaseState == purchased`, and then insert the
server-verified row. A repeated token for the same user returns
`alreadyRecorded`; a token belonging to a different user returns a conflict.
The response includes `granted`, `alreadyRecorded`, `goldAmount`, and
`entitlementId` so the client can reconcile both product types.

The scheduled voided-purchase function will mark both Gold and entitlement
rows as `refunded`. During the next account sync, `CloudSyncService` will:

- deliver only active Gold rows to the Gold ledger;
- grant the local Remove Ads entitlement when an active `remove_ads` row exists;
- revoke the local Remove Ads entitlement when the server reports that the
  entitlement has been refunded;
- avoid treating a transient query failure as a refund.

No service-role key or Google service-account JSON is placed in the Flutter
application. The Edge Functions continue to own those secrets.

## Flutter architecture

### AdMob configuration

Add the pinned `google_mobile_ads` dependency and an `AdMobConfig` abstraction.
The Android application manifest will receive the real AdMob application ID
from a non-secret build configuration, and the release build will contain the
real production banner/interstitial unit IDs. Debug builds may opt into
Google's test units through a build flag; this is a development safeguard and
does not change the production configuration.

The application will initialize the SDK once and continue normally if
initialization fails. Test devices must be registered as AdMob test devices
when real unit IDs are used during Internal/Closed Testing; testers must never
click live ads.

`AdService` will own lifecycle and eligibility:

- `adsEnabled` is false when `SaveService.removeAds` is true;
- a banner load failure renders a reserved, empty-safe area and schedules a
  bounded retry;
- an interstitial is preloaded only outside active gameplay;
- `showInterstitialIfEligible` returns without doing anything when ads are
  disabled, an interstitial is not ready, the app is not mounted, or the
  cooldown is active;
- every loaded ad is disposed after use or failure;
- debug builds use test ad units; release AABs, including the Closed Testing
  artifact, use the production unit IDs and rely on registered test devices
  during validation. Testers are never encouraged to click an ad.

`AdBanner` will be a reusable widget. It will render a compact banner at the
bottom of the main menu, Collection, and Booster layouts, with no banner in a
duel or PvP route. It listens to the saved entitlement so it disappears after
the purchase without requiring an app restart.

### Placement rules

| Surface | Ad |
| --- | --- |
| Main menu | banner at the bottom of the scrollable content |
| Collection | banner below the filters/card list area |
| Booster | banner below the pack controls/results |
| Local Duel | interstitial after result/reward, before returning |
| Story | interstitial after victory/defeat result flow, before returning |
| Arena | interstitial after the run summary, before the run is reset |
| PvP | no ads during or after the match |

The interstitial call is injected into the local result path rather than the
generic `DuelScreen`, which prevents accidental ads during gameplay and keeps
PvP isolated. The call is best-effort; a missing ad never blocks navigation or
rewards. A short session cooldown prevents repeated ads when a player chains
local battles.

### Remove Ads UX

Settings will show a dedicated monetization row:

- before purchase: “Remove Ads · US$4.99” with a one-tap purchase action;
- while purchasing: disabled action with progress state;
- pending: explains that Google Play is completing the transaction;
- owned: “Ads removed” and a Restore action;
- error: concise retry message without exposing receipt data.

The row will not be shown as a paywall over gameplay. The current signed-in
account copy will be updated to mention that the entitlement is recoverable on
another device after sign-in.

## External console work

### Google Play Console

For the existing Android app, configure the in-app product:

- product ID `remove_ads`;
- product type non-consumable / one-time product;
- default price US$4.99;
- item title and description consistent with the in-app copy;
- keep the existing Gold product unchanged.

Mark the app as containing ads in App content. Update the Data safety answers
to reflect the selected Google Mobile Ads SDK behavior only when the console
requires those declarations for this app's actual data practices. Keep the
new Android App Bundle in Internal or Closed testing; do not send it to
Production.

### AdMob

Use the already-open AdMob account/tab to ensure the Android app is registered
for package `com.shardfall.shardfall`, then create one production banner unit
and one production interstitial unit. Record the resulting IDs in the app's
non-secret release configuration and keep a separate debug/test-unit switch.
If the account requires app verification, app-ads.txt, or a review before live
serving, complete every available setup step and report the exact remaining
approval. The app must not silently fall back to fabricated IDs.

## Testing strategy

Tests are written first and must fail before the corresponding implementation:

1. Catalog tests verify `remove_ads`, product classification, and the unchanged
   500 Gold mapping.
2. Remove Ads purchase-service tests cover query, purchase, restore, pending,
   idempotency, completion, backend retry, and a purchase token belonging to a
   different account being surfaced as an error.
3. Save tests cover persistence, cloud snapshot round-trip, idempotent grant,
   refund/revocation, and old snapshots that lack the new field.
4. Ad service tests cover the no-op path when Remove Ads is owned, load failure,
   disposal, cooldown, and best-effort interstitial behavior. Platform ad
   objects are injected behind test seams; Flutter widget tests do not require a
   real AdMob network.
5. Widget tests verify banners appear only on approved surfaces and disappear
   after the entitlement changes.
6. Supabase migration/function checks verify the table constraint, RLS read
   scope, product mapping, token idempotency, and refunded entitlement sync.
7. Final local verification runs `flutter pub get`, `flutter test`,
   `flutter analyze`, and a release AAB build. The exact AAB version code is
   checked before upload so an older artifact cannot replace the intended test
   build.

## Rollout and rollback

Implementation is committed on the current branch after tests pass. Supabase
migrations and Edge Functions are deployed before the client build is offered
to testers, so a new client cannot strand a verified purchase. The Play
Console product and AdMob units are configured for Production now, but the
new AAB is offered only through Internal/Closed Testing in this task.

The release build reads the real production AdMob IDs already configured in
the app. Therefore, once Google approves the Play listing/release and AdMob is
allowed to serve, the live app can start showing ads immediately without a
second code change. Any remaining Google approval or policy gate is an
external dependency and will be reported explicitly.

If AdMob fails, the app remains playable and the Remove Ads purchase remains
available. If the new entitlement migration is not deployable, the client
build is not uploaded. If a Play Console or AdMob action asks for an
irreversible Production decision, stop at that screen and hand it back to the
owner.

## Acceptance criteria

- A fresh install can see a banner on the three approved screens and no ad in
  a live local or PvP match.
- A successful test purchase of `remove_ads` at US$4.99 hides all banners and
  makes eligible interstitial calls no-op.
- Restart, restore, sign-in on another device, and a backend retry preserve the
  entitlement without duplicate ledger rows.
- A server-marked refund makes the entitlement revocable on the next sync.
- Existing `gold_500` purchase tests and behavior remain green.
- The Play Console product, “contains ads” declaration, and real production
  AdMob units are configured, the release build contains those IDs, and no
  Production release was started by this task.
