# Shardfall Gold Purchase and Play Billing Design

Date: 2026-08-01  
Status: Approved by user for implementation

## Goal

Add an optional purchase flow that lets players buy 500 Gold for US$1.00 and use that Gold to open Shard Packs. Configure the matching Google Play one-time product, prepare a signed closed-testing build, push the implementation, and make the existing YouTube trailer public.

## Product decisions

- Product ID: `gold_500`
- Product type: consumable one-time product
- Grant: 500 Gold per successful purchase
- Base price: US$1.00; Google Play may show a localized equivalent to the user
- Use: Gold remains the existing soft currency and a Shard Pack costs 100 Gold
- Platforms: Android / Google Play only for this iteration
- Testing boundary: prepare the closed-testing release; do not submit production access or publish the app to production
- YouTube: change `https://youtu.be/odO1Ks-SkW8` from Unlisted to Public after the app changes are ready

Google Play treats in-game currency as a consumable product. A successful purchase must be processed, delivered, and completed/consumed so the product can be purchased again.

## Chosen approach

Use Flutter's official `in_app_purchase` package behind a focused `GoldPurchaseService` rather than calling Android BillingClient directly from Kotlin.

Alternatives considered:

1. **Flutter `in_app_purchase` (chosen).** Fits the existing Flutter app, keeps the purchase UI in Dart, uses the store-provided localized price, and avoids a platform channel. It also keeps the code ready for a future storefront adapter.
2. **Native Android BillingClient via MethodChannel.** Gives Android-specific control over acknowledgement and consumption, but adds a second API surface and more lifecycle code for a game that currently has no native purchase layer.
3. **External payment page or local-only Gold button.** Not suitable for digital currency sold in a Google Play app and would not create a valid Play Billing purchase flow.

## Architecture

### Purchase service

Add `GoldPurchaseService` under `app/lib/services/`.

Responsibilities:

- Subscribe to `InAppPurchase.instance.purchaseStream` as early as the loaded game session allows.
- Check store availability and query the `gold_500` product details.
- Expose loading, available, unavailable, purchasing, pending, success, and error state to the UI through `ChangeNotifier`.
- Start a consumable purchase using the product details returned by Google Play.
- Grant Gold only for a purchase with `PurchaseStatus.purchased`.
- Complete eligible purchased transactions after delivery and use the plugin's consumable flow so the item can be bought again. Leave `pending` transactions ungranted and incomplete until Google Play reports them as purchased.
- Never grant Gold for canceled, pending, or errored purchases.
- Keep platform behavior safe: Android uses Google Play; other platforms show the product as unavailable rather than offering a fake payment path.

`MenuScreen` owns the service after `SaveService` is loaded, initializes it once, passes it into `BoosterScreen`, and disposes it with the screen lifecycle.

### Save and idempotency

Extend `SaveService` with a small local set of processed purchase identifiers and a method that grants a product's Gold exactly once. The set is persisted with the existing SharedPreferences save.

The delivery sequence is:

1. Receive a purchase update.
2. Confirm the product ID is `gold_500` and the purchase state is `purchased`.
3. If its transaction identifier has not been processed, add 500 Gold and persist the identifier atomically with the currency update.
4. Complete the purchase with the store.
5. Notify the UI so the updated Gold balance is visible.

This is appropriate for the current offline closed-test architecture and prevents duplicate grants when a purchase callback is replayed. It is not a complete anti-fraud system: there is no account identity or secure backend in the current game. Server-side purchase verification, refunds, and cross-device entitlements remain a pre-production hardening item.

Existing local backup/export behavior will remain unchanged in this iteration so current offline progress continues to work. The known implication is that a local save containing Gold is not a secure source of truth across devices.

### Booster UI

Add a compact `BUY GOLD` panel to the sealed-pack state of `BoosterScreen`, matching the existing dark fantasy / gold accent style.

The panel will show:

- `500 GOLD`
- the localized Play price when product details are available
- a primary `BUY NOW` action
- a clear loading or unavailable state when Play Billing is not ready
- a success message showing the updated Gold balance
- an explanatory message for canceled, pending, or failed purchases

The existing pack-opening interaction and 100 Gold cost remain unchanged. The buy panel is optional and does not block earning Gold through duels, story battles, quests, and daily rewards.

## Play Console configuration

Configure the app's one-time product catalog:

- Product ID: `gold_500`
- Name: `500 Gold`
- Description: `Add 500 Gold to your Shardfall balance for opening Shard Packs.`
- Price: US$1.00 base price
- Product status: active
- Availability: all supported countries/regions unless Play requires a narrower selection

If the developer account requires a merchant/payment profile, tax profile, or bank/payout verification that cannot be completed from the current console session, leave the product at the exact blocking step and report it rather than claiming payment activation is complete.

Upload the incremented, release-signed AAB to the existing Closed testing track as a new release draft. Do not send it to production. The user can complete the review/rollout and tester communication.

## YouTube handoff

Set the existing Shardfall trailer to Public after the Play Console and build steps are complete. Verify the same watch URL remains available and keep the YouTube tab on the published video for handoff.

## Error handling

- Store unavailable: show that purchases are unavailable on this device/platform and keep the offline game playable.
- Product missing: show a configuration message rather than a hard-coded fake price.
- Purchase canceled: show a non-blocking cancellation message; do not add Gold.
- Purchase pending: show that Gold will arrive after Google Play confirms payment; do not add Gold yet.
- Purchase error: show a retryable error and keep the Booster screen usable.
- Replayed purchase update: ignore the already-processed transaction identifier, then complete the store transaction if needed.
- Existing save or store initialization failure: preserve the local game flow and surface the purchase failure without crashing the app.

## Verification plan

### Automated checks

- Add unit coverage for `SaveService` purchase delivery: first delivery grants 500 Gold, duplicate transaction delivery grants nothing, and unknown products are rejected.
- Run `flutter analyze`.
- Run the existing Flutter and engine test suites.
- Build the release AAB with the existing local upload key and verify the output.

### Console checks

- Confirm `gold_500` is active and priced at US$1.00.
- Confirm the closed-test release draft contains the incremented version and signed AAB.
- Confirm the trailer is Public and the Play Store listing still references its YouTube URL.

## Out of scope

- Subscriptions or additional Gold bundles
- iOS/App Store billing
- Server-side receipt verification, refund handling, and cross-device paid entitlements
- Production rollout or production-access application
