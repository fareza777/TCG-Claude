# Shardfall Ads Monetization and Remove Ads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship production-ready AdMob banners/interstitials and a Google Play non-consumable `remove_ads` product priced at US$4.99, while distributing the new Android build only through Internal/Closed Testing.

**Architecture:** Keep the existing `GoldPurchaseService` consumable flow intact and add a separate `RemoveAdsPurchaseService` with the same server-verification contract. Store the entitlement locally for offline continuity, but make Supabase's Google-verified purchase ledger the cross-device authority. Centralize ad eligibility in `AdService`; only explicit local result paths may request an interstitial.

**Tech Stack:** Flutter/Dart, `in_app_purchase`, `google_mobile_ads`, SharedPreferences, Supabase Postgres migrations, Supabase Edge Functions/Deno, Google Play Console, AdMob, Flutter widget/unit tests, Android App Bundle.

**Spec:** `docs/superpowers/specs/2026-08-20-ads-remove-ads-design.md`

## Global Constraints

- Product IDs are exactly `gold_500` and `remove_ads`; `gold_500` continues granting exactly 500 Gold.
- `remove_ads` is a Google Play non-consumable/one-time product priced at US$4.99.
- Banner placement is limited to the main menu, Collection, and Booster screens.
- Interstitials occur only after local Duel, Story, or Arena result/reward flows; never during gameplay and never in PvP.
- Completed Play purchases suppress ads locally immediately; backend verification is retried and never trusts a client-supplied price.
- The Supabase purchase ledger remains service-role write-only and owner-readable through RLS; no service-role key or Google service-account JSON enters Flutter.
- Release AABs use the real production AdMob App ID and unit IDs; debug builds may use Google's test units.
- The Play product and AdMob units are configured for eventual Production, but this work must not publish a Production release.
- Tests are written before the implementation for each new behavior, followed by fresh `flutter test`, `flutter analyze`, and release AAB verification.

---

### Task 1: Establish a clean baseline and dependency boundary

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/pubspec.lock`
- Test: existing `app/test/gold_purchase_service_test.dart`, `app/test/save_service_purchase_test.dart`

**Interfaces:**
- Consumes: the current Flutter SDK constraints and existing purchase dependencies.
- Produces: a reproducible dependency lock and a recorded green baseline before new tests are added.

- [ ] **Step 1: Confirm repository state and current tool versions**

Run:

```powershell
git status --short --branch
flutter --version
flutter pub deps --style=compact
```

Expected: the worktree is clean or any pre-existing user changes are recorded before editing; Flutter resolves the current project; `in_app_purchase` is already present.

- [ ] **Step 2: Run the existing purchase and save tests**

Run:

```powershell
flutter test test/gold_purchase_service_test.dart test/save_service_purchase_test.dart test/save_service_snapshot_test.dart
```

Expected: PASS. If a pre-existing test fails, stop and fix the baseline before adding monetization behavior.

- [ ] **Step 3: Add the AdMob dependency without changing the purchase API**

Run:

```powershell
flutter pub add google_mobile_ads
```

Then inspect `app/pubspec.yaml` and keep the resolved version in `app/pubspec.lock`. Do not replace `in_app_purchase` or change the existing SDK constraint.

- [ ] **Step 4: Re-run the baseline after dependency resolution**

Run:

```powershell
flutter test test/gold_purchase_service_test.dart test/save_service_purchase_test.dart test/save_service_snapshot_test.dart
```

Expected: PASS with the existing Gold behavior unchanged.

- [ ] **Step 5: Commit the dependency boundary**

```powershell
git add app/pubspec.yaml app/pubspec.lock
git commit -m "build: add Google Mobile Ads dependency"
```

### Task 2: Add the Remove Ads catalog and durable local entitlement

**Files:**
- Modify: `app/lib/services/purchase_catalog.dart`
- Modify: `app/lib/services/save_service.dart`
- Test: `app/test/remove_ads_entitlement_test.dart`
- Test: `app/test/save_service_snapshot_test.dart`

**Interfaces:**
- Consumes: current `SaveService` purchase ledgers and SharedPreferences persistence.
- Produces: `PurchaseCatalog.removeAdsId`, `SaveService.removeAds`, `SaveService.grantRemoveAds`, and `SaveService.revokeRemoveAds`.

- [ ] **Step 1: Write failing catalog and entitlement tests**

Create `app/test/remove_ads_entitlement_test.dart` with tests for the exact contract:

```dart
test('catalog exposes a non-consumable remove ads product', () {
  expect(PurchaseCatalog.removeAdsId, 'remove_ads');
  expect(PurchaseCatalog.productIds, contains('remove_ads'));
  expect(PurchaseCatalog.gold500Amount, 500);
});

test('grants remove ads once and persists it', () async {
  final save = await SaveService.load(emptyLibrary);

  expect(await save.grantRemoveAds(
    productId: PurchaseCatalog.removeAdsId,
    purchaseId: 'remove-token-1',
  ), isTrue);
  expect(await save.grantRemoveAds(
    productId: PurchaseCatalog.removeAdsId,
    purchaseId: 'remove-token-1',
  ), isFalse);
  expect(save.removeAds, isTrue);

  final reloaded = await SaveService.load(emptyLibrary);
  expect(reloaded.removeAds, isTrue);
});

test('revoking one entitlement token does not revoke another active token', () async {
  final save = await SaveService.load(emptyLibrary);
  await save.grantRemoveAds(productId: 'remove_ads', purchaseId: 'token-a');
  await save.grantRemoveAds(productId: 'remove_ads', purchaseId: 'token-b');

  expect(await save.revokeRemoveAds(
    productId: 'remove_ads', purchaseId: 'token-a'), isTrue);
  expect(save.removeAds, isTrue);
  expect(await save.revokeRemoveAds(
    productId: 'remove_ads', purchaseId: 'token-b'), isTrue);
  expect(save.removeAds, isFalse);
});
```

Also add a snapshot round-trip assertion that `removeAds` and its purchase identifiers survive JSON encoding and an old snapshot without those fields does not clear a local entitlement.

- [ ] **Step 2: Run the new tests to confirm they fail**

Run:

```powershell
flutter test test/remove_ads_entitlement_test.dart test/save_service_snapshot_test.dart
```

Expected: FAIL because the catalog ID, entitlement field, and methods do not yet exist.

- [ ] **Step 3: Extend the catalog and local ledger minimally**

In `app/lib/services/purchase_catalog.dart` add:

```dart
static const removeAdsId = 'remove_ads';
static const productIds = <String>{gold500Id, removeAdsId};
```

In `SaveService` add a persisted `bool removeAds = false`, a `Set<String> removeAdsPurchaseIds`, and use the existing `revokedPurchaseIds` for refund blocking. Implement:

```dart
Future<bool> grantRemoveAds({
  required String productId,
  required String purchaseId,
  Set<String> aliasIds = const {},
});

Future<bool> revokeRemoveAds({
  required String productId,
  required String purchaseId,
  Set<String> aliasIds = const {},
});
```

Both methods trim and reject empty identifiers. Granting rejects any product except `remove_ads`, blocks identifiers already in `revokedPurchaseIds`, unions aliases, sets `removeAds = true`, persists, and notifies only when a new active identifier is delivered. Revoking records all identifiers, removes them from `removeAdsPurchaseIds`, sets `removeAds` to whether another active identifier remains, persists, and notifies when the visible entitlement changes.

Load/save the following keys: `removeAds`, `removeAdsPurchaseIds`. Include both in `toSnapshot()` and `applySnapshot()`. `applySnapshot()` must union purchase identifier sets and use a missing `removeAds` field as “keep the current value” so old cloud snapshots cannot erase a local purchase.

- [ ] **Step 4: Run the entitlement and regression tests**

Run:

```powershell
flutter test test/remove_ads_entitlement_test.dart test/save_service_purchase_test.dart test/save_service_snapshot_test.dart
```

Expected: PASS, including all existing Gold refund/idempotency tests.

- [ ] **Step 5: Commit the local entitlement boundary**

```powershell
git add app/lib/services/purchase_catalog.dart app/lib/services/save_service.dart app/test/remove_ads_entitlement_test.dart app/test/save_service_snapshot_test.dart
git commit -m "feat: persist remove ads entitlement"
```

### Task 3: Implement the non-consumable Google Play purchase service

**Files:**
- Create: `app/lib/services/purchase_verifier.dart`
- Create: `app/lib/services/remove_ads_purchase_service.dart`
- Modify: `app/lib/services/gold_purchase_service.dart`
- Test: `app/test/remove_ads_purchase_service_test.dart`

**Interfaces:**
- Consumes: `PurchaseCatalog.removeAdsId`, `SaveService.grantRemoveAds`, and the existing backend verifier signature.
- Produces: `RemoveAdsPurchaseService`, `RemoveAdsStore`, `FlutterRemoveAdsStore`, `RemoveAdsPurchaseState`, `canBuy`, `priceLabel`, `buyRemoveAds()`, and `restorePurchases()`.

- [ ] **Step 1: Extract the shared verifier typedef and write failing service tests**

Move the existing `PurchaseVerifier` typedef to `app/lib/services/purchase_verifier.dart` and import it from Gold. Before implementing the new service, add a fake `RemoveAdsStore` and tests covering:

```dart
test('loads remove ads and restores owned purchases', () async { /* query, restore, owned */ });
test('starts a non-consumable purchase with the product details', () async { /* buyNonConsumable */ });
test('handles pending and canceled states without granting access', () async { /* state */ });
test('delivers a purchased token once and completes it', () async { /* grant, complete */ });
test('queues local ownership for backend retry when verification fails', () async { /* unverifiedPurchases */ });
test('ignores Gold and unknown products', () async { /* no entitlement */ });
```

The fake purchase must use `serverVerificationData` as the token and `purchaseID` as the alias, matching the existing Gold tests.

- [ ] **Step 2: Run the new service tests to confirm they fail**

Run:

```powershell
flutter test test/remove_ads_purchase_service_test.dart
```

Expected: FAIL because the service and store interfaces do not exist.

- [ ] **Step 3: Implement the store adapter and state machine**

Define:

```dart
enum RemoveAdsPurchaseState {
  loading, ready, unavailable, purchasing, pending, owned, error,
}

abstract interface class RemoveAdsStore {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases();
}
```

`FlutterRemoveAdsStore` delegates to `InAppPurchase.instance` and calls `buyNonConsumable`. `RemoveAdsPurchaseService.initialize()` subscribes before querying, restricts itself to Android, filters exactly `remove_ads`, restores purchases, and remains usable when restore fails. `_deliverPurchase()` accepts `purchased`/`restored`, derives token/order identifiers, grants locally idempotently, completes pending platform purchases, and queues `remove_ads|token` for the shared verifier. A verified or already-recorded response removes the queue item. Errors expose user-safe text and never log receipt tokens.

- [ ] **Step 4: Run focused and regression tests**

Run:

```powershell
flutter test test/remove_ads_purchase_service_test.dart test/gold_purchase_service_test.dart test/save_service_purchase_test.dart
```

Expected: PASS with Gold behavior unchanged and Remove Ads states correct.

- [ ] **Step 5: Commit the non-consumable purchase flow**

```powershell
git add app/lib/services/purchase_verifier.dart app/lib/services/remove_ads_purchase_service.dart app/lib/services/gold_purchase_service.dart app/test/remove_ads_purchase_service_test.dart
git commit -m "feat: add remove ads Play purchase flow"
```

### Task 4: Extend the Supabase ledger and receipt verification

**Files:**
- Create: `supabase/migrations/20260820140000_remove_ads_entitlement.sql`
- Create: `supabase/functions/_shared/purchase_catalog.ts`
- Modify: `supabase/functions/verify-purchase/index.ts`
- Create: `supabase/functions/verify-purchase/catalog_test.ts`
- Create: `supabase/tests/purchases_entitlement.sql`

**Interfaces:**
- Consumes: current `public.purchases`, Google Play product endpoint, and Edge Function secrets.
- Produces: a nullable `entitlement_id` ledger column, `purchased_remove_ads()` helper, catalog mapping for `remove_ads`, and idempotent verified responses containing `entitlementId`.

- [ ] **Step 1: Write failing catalog and SQL contract tests**

Create the pure Deno catalog test:

```ts
Deno.test("remove_ads is a non-consumable entitlement", () => {
  const product = PLAY_PRODUCTS.remove_ads;
  if (product.goldAmount !== null || product.entitlementId !== "remove_ads") {
    throw new Error("remove_ads catalog contract changed");
  }
});
```

Create `supabase/tests/purchases_entitlement.sql` to assert the migration exposes `entitlement_id`, keeps `gold_amount` nullable, and exposes `public.purchased_remove_ads()`. The test must also verify that the RLS policy is still select-only for the owner by inspecting `pg_policies` and that the purchase-token unique constraint remains present.

- [ ] **Step 2: Run the tests against the current schema to confirm the new contract fails**

Run:

```powershell
deno test supabase/functions/verify-purchase/catalog_test.ts
supabase test db supabase/tests/purchases_entitlement.sql
```

Expected: the catalog test fails because the shared mapping is absent; the SQL contract reports the new column/function as absent until the migration is applied.

- [ ] **Step 3: Add a backwards-compatible entitlement migration**

In `20260820140000_remove_ads_entitlement.sql`:

```sql
alter table public.purchases
  drop constraint purchases_gold_amount_check;

alter table public.purchases
  alter column gold_amount drop not null;

alter table public.purchases
  add column entitlement_id text;

alter table public.purchases
  add constraint purchases_value_shape_check check (
    (product_id = 'gold_500' and gold_amount is not null and gold_amount > 0 and entitlement_id is null)
    or
    (product_id = 'remove_ads' and gold_amount is null and entitlement_id = 'remove_ads')
  );

create index purchases_entitlement_state_idx
  on public.purchases (user_id, entitlement_id, state);
```

Replace the old Gold total function with an equivalent function that still sums only granted Gold rows, and add a security-invoker `public.purchased_remove_ads()` function that checks the signed-in caller's granted `remove_ads` rows. Preserve the existing RLS policy and do not add client insert/update/delete policies.

- [ ] **Step 4: Implement the shared server catalog and verifier mapping**

Create `PLAY_PRODUCTS` with exact entries:

```ts
export const PLAY_PRODUCTS = {
  gold_500: { goldAmount: 500, entitlementId: null },
  remove_ads: { goldAmount: null, entitlementId: "remove_ads" },
} as const;
```

Update `verify-purchase/index.ts` to reject product IDs outside that map, select `entitlement_id` in the existing-token lookup, insert `gold_amount` and `entitlement_id` according to the catalog, and return `goldAmount` plus `entitlementId` for both new and already-recorded responses. Keep the Google receipt call product-specific, require `purchaseState === 0`, keep the token conflict response, and never log the token or raw receipt.

- [ ] **Step 5: Run local schema and function checks after implementation**

Run:

```powershell
deno test supabase/functions/verify-purchase/catalog_test.ts
supabase test db supabase/tests/purchases_entitlement.sql
```

Expected: PASS. Inspect the generated schema to confirm existing Gold rows satisfy the new check before applying it to the remote project.

- [ ] **Step 6: Commit the backend contract**

```powershell
git add supabase/migrations/20260820140000_remove_ads_entitlement.sql supabase/functions/_shared/purchase_catalog.ts supabase/functions/verify-purchase/index.ts supabase/functions/verify-purchase/catalog_test.ts supabase/tests/purchases_entitlement.sql
git commit -m "feat: verify remove ads entitlement server-side"
```

### Task 5: Reconcile active and refunded entitlements during cloud sync

**Files:**
- Modify: `app/lib/services/cloud_sync_service.dart`
- Test: `app/test/cloud_sync_entitlement_test.dart`
- Modify: `supabase/functions/sync-voided-purchases/index.ts`

**Interfaces:**
- Consumes: rows shaped as `product_id`, `purchase_token`, `order_id`, `state`, and the local Gold/Remove Ads ledger methods.
- Produces: additive, idempotent reconciliation that grants active `remove_ads` rows and revokes only refunded entitlement identifiers.

- [ ] **Step 1: Write failing reconciliation tests**

Extract a testable `@visibleForTesting` method from `CloudSyncService`:

```dart
Future<int> applyPurchaseRows(Iterable<Map<String, dynamic>> rows);
```

Add tests for active Remove Ads, refunded Remove Ads, active Gold, unknown products, duplicate rows, and a transient query failure path that does not revoke anything. The active entitlement case must leave `save.removeAds == true`; the refunded case must leave it false only after its active identifiers are exhausted.

- [ ] **Step 2: Run the new reconciliation tests to confirm they fail**

Run:

```powershell
flutter test test/cloud_sync_entitlement_test.dart
```

Expected: FAIL because current sync treats every row as Gold and has no Remove Ads branch.

- [ ] **Step 3: Implement row reconciliation without changing profile conflict behavior**

Update `restoreEntitlements()` to select the existing fields plus `entitlement_id`, then delegate rows to `applyPurchaseRows`. Branch by product ID:

```dart
if (productId == PurchaseCatalog.gold500Id) {
  // existing grant/revoke Gold path
} else if (productId == PurchaseCatalog.removeAdsId) {
  // grant/revoke Remove Ads with token and order alias
}
```

Calculate `recoveredGold` only from newly delivered Gold rows. A failed query returns without applying revocations. Keep `syncOnSignIn()` ordering: retry local receipts, restore server entitlements, then resolve cloud-save conflict.

- [ ] **Step 4: Confirm voided sync remains product-agnostic and safe**

Update comments and tests around `sync-voided-purchases` to assert it marks both Gold and `remove_ads` rows as `refunded` using the existing token list and never accepts a player JWT in place of the configured service key. Do not change the scheduled job URL or secrets.

- [ ] **Step 5: Run focused tests and commit**

Run:

```powershell
flutter test test/cloud_sync_entitlement_test.dart test/save_service_purchase_test.dart test/save_service_snapshot_test.dart
deno test supabase/functions/verify-purchase/catalog_test.ts
```

Expected: PASS.

```powershell
git add app/lib/services/cloud_sync_service.dart app/test/cloud_sync_entitlement_test.dart supabase/functions/sync-voided-purchases/index.ts
git commit -m "feat: restore and revoke remove ads entitlement"
```

### Task 6: Build the production-ready AdMob service and eligibility policy

**Files:**
- Create: `app/lib/services/ad_config.dart`
- Create: `app/lib/services/ad_service.dart`
- Create: `app/test/ad_service_test.dart`

**Interfaces:**
- Consumes: `SaveService.removeAds`, real production IDs supplied after AdMob setup, and `google_mobile_ads`.
- Produces: `AdService.initialize()`, `adsEnabled`, `showInterstitialIfEligible()`, `preloadInterstitial()`, `AdBanner`-consumable banner state, and testable policy seams.

- [ ] **Step 1: Write failing pure eligibility tests**

Add tests that assert:

```dart
expect(AdPolicy.canShowBanner(removeAds: false), isTrue);
expect(AdPolicy.canShowBanner(removeAds: true), isFalse);
expect(AdPolicy.canShowInterstitial(removeAds: false, ready: false, inCooldown: false), isFalse);
expect(AdPolicy.canShowInterstitial(removeAds: false, ready: true, inCooldown: false), isTrue);
expect(AdPolicy.canShowInterstitial(removeAds: true, ready: true, inCooldown: false), isFalse);
```

Also test that `AdService` applies a cooldown, disposes a consumed interstitial, and treats load/show errors as best-effort failures.

- [ ] **Step 2: Run the new tests to confirm they fail**

Run:

```powershell
flutter test test/ad_service_test.dart
```

Expected: FAIL because `AdPolicy` and `AdService` do not exist.

- [ ] **Step 3: Implement configuration and policy**

Create `AdMobConfig` with the real app/unit values wired after Task 9, plus Google's official test unit IDs for debug mode. Use `kReleaseMode`/`ADMOB_USE_TEST_ADS` so debug tests never need a live network. Keep the App ID and unit IDs public configuration, not secrets; keep service credentials out of Dart.

Implement `AdPolicy` as pure functions and `AdService` as a `ChangeNotifier` that:

- listens to `SaveService` and publishes `adsEnabled == !save.removeAds`;
- initializes `MobileAds.instance` once and catches initialization errors;
- loads a banner only when eligible and reports a safe empty state on failure;
- preloads/disposes interstitials with an injectable clock and platform seam;
- has `Future<bool> showInterstitialIfEligible()` that returns false without blocking navigation when Remove Ads is owned, no ad is ready, cooldown is active, or the platform fails.

Do not put an ad call in `DuelScreen`, `PvpBattleScreen`, or any generic route lifecycle.

- [ ] **Step 4: Run focused tests and commit**

Run:

```powershell
flutter test test/ad_service_test.dart
```

Expected: PASS.

```powershell
git add app/lib/services/ad_config.dart app/lib/services/ad_service.dart app/test/ad_service_test.dart
git commit -m "feat: add production-ready ad service"
```

### Task 7: Add banner widget, Settings purchase UI, and dependency wiring

**Files:**
- Create: `app/lib/widgets/ad_banner.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/collection/collection_screen.dart`
- Modify: `app/lib/packs/booster_screen.dart`
- Test: `app/test/ad_banner_test.dart`

**Interfaces:**
- Consumes: `AdService`, `RemoveAdsPurchaseService`, and `SaveService`.
- Produces: a reusable `AdBanner(adService: ...)` and a Settings row that purchases/restores `remove_ads`.

- [ ] **Step 1: Write failing widget tests**

Add tests that pump `AdBanner` with a fake service and assert it renders the reserved ad area only when `adsEnabled` is true, disappears after the entitlement changes, and never creates a platform ad when disabled. Add a Settings test that renders `US$4.99`, changes to a purchasing state, and exposes Restore when owned.

- [ ] **Step 2: Run widget tests to confirm they fail**

Run:

```powershell
flutter test test/ad_banner_test.dart
```

Expected: FAIL because the widget and Settings purchase service are not wired.

- [ ] **Step 3: Implement the banner widget and screen placements**

`AdBanner` must be bounded, safe-area aware, and render nothing when `adsEnabled` is false or the banner has no loaded ad. Add it to:

- the bottom of the main menu content;
- the bottom of Collection below the list/filter area;
- the bottom of Booster below pack controls/results.

Do not add it to Story, Arena, Duel, or PvP routes. Use `ListenableBuilder`/`AnimatedBuilder` so the widget disappears immediately after purchase.

- [ ] **Step 4: Wire Remove Ads into startup and Settings**

In `_MenuScreenState._load()` create one `RemoveAdsPurchaseService(save: save, verifier: cloud.verifyPurchase)` and one `AdService(save: save)`, initialize both after assigning state, and dispose them with the menu state. Pass the service to `BoosterScreen` only if needed for shared listeners; Settings owns the purchase action.

Add a Settings monetization section using `ListenableBuilder` over the Remove Ads service and SaveService. The row uses the Play product's localized `price` when available, falls back to `US$4.99` only before Play returns a price, calls `buyRemoveAds()`, and offers `restorePurchases()` when owned. User-facing errors contain no token or receipt data.

- [ ] **Step 5: Run widget and purchase regression tests**

Run:

```powershell
flutter test test/ad_banner_test.dart test/remove_ads_purchase_service_test.dart test/gold_purchase_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit UI wiring**

```powershell
git add app/lib/widgets/ad_banner.dart app/lib/main.dart app/lib/collection/collection_screen.dart app/lib/packs/booster_screen.dart app/test/ad_banner_test.dart
git commit -m "feat: add ads placements and remove ads settings"
```

### Task 8: Trigger interstitials only from local result flows

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/lib/story/story_screen.dart`
- Modify: `app/lib/story/chapter_player.dart`
- Modify: `app/lib/arena/arena_screen.dart`
- Test: `app/test/ad_result_flow_test.dart`

**Interfaces:**
- Consumes: `AdService.showInterstitialIfEligible()`.
- Produces: best-effort post-result calls with no PvP or active-gameplay call sites.

- [ ] **Step 1: Write failing result-flow tests**

Add a fake `AdService` counter and assert:

```dart
expect(localDuelResult.interstitialCalls, 1);
expect(storyVictoryResult.interstitialCalls, 1);
expect(arenaRunOverResult.interstitialCalls, 1);
expect(pvpMatchResult.interstitialCalls, 0);
expect(activeDuelResult.interstitialCalls, 0);
```

The test must also assert reward persistence happens before the interstitial call and that a failed ad does not prevent navigation.

- [ ] **Step 2: Run the flow tests to confirm they fail**

Run:

```powershell
flutter test test/ad_result_flow_test.dart
```

Expected: FAIL because the result flows do not receive an ad service.

- [ ] **Step 3: Wire the local Duel result**

Pass `AdService` into `_MenuScreenState._launchDuel()` and call:

```dart
await _save!.addGold(SaveService.duelWinGold);
await _save!.trackQuest('duel_win');
await _ads!.showInterstitialIfEligible();
```

Call it after a win result/reward is committed, and after a loss result if the route returns normally. Never add it to `DuelScreen`.

- [ ] **Step 4: Wire Story and Arena results**

Pass `AdService` through `StoryScreen -> ChapterMapScreen -> ChapterPlayerScreen -> _BattleIntro`. In `_BattleIntro._fight()`, finish Gold/quest/victory dialog work, then await `showInterstitialIfEligible()` before `onVictory()`.

Pass `AdService` into `ArenaScreen`. In `_endRun()`, finish `recordArenaRun()` and the run summary dialog, then await the interstitial before resetting `_runActive`.

Do not pass the service into `PvpLobbyScreen`, `PvpBattleScreen`, or `DuelScreen`.

- [ ] **Step 5: Run flow and PVP regression tests**

Run:

```powershell
flutter test test/ad_result_flow_test.dart test/pvp_controller_test.dart test/pvp_duel_controller_test.dart
```

Expected: PASS, with no PVP behavior change.

- [ ] **Step 6: Commit result-flow integration**

```powershell
git add app/lib/main.dart app/lib/story/story_screen.dart app/lib/story/chapter_player.dart app/lib/arena/arena_screen.dart app/test/ad_result_flow_test.dart
git commit -m "feat: show post-result interstitials outside PvP"
```

### Task 9: Configure AdMob and Google Play for Production readiness

**Files:**
- No repository files until the exact AdMob IDs are returned; IDs are consumed by Task 10.
- External: AdMob app and ad units for `com.shardfall.shardfall`.
- External: Google Play Console one-time product and App content declarations.

**Interfaces:**
- Consumes: the already-open Chrome tabs and the existing Play app.
- Produces: active production AdMob App/banner/interstitial IDs, active `remove_ads` product at US$4.99, “contains ads” declaration, and no Production release action.

- [ ] **Step 1: Identify the exact open AdMob and Play tabs**

Use the Chrome control skill to inspect open tabs, claim only the existing AdMob and Play Console tabs, and verify the signed-in account and package/application context before changing anything. Do not navigate or submit from an unrelated tab.

- [ ] **Step 2: Register or verify the Android app in AdMob**

In AdMob, use Android app package `com.shardfall.shardfall`. If the app is already registered, reuse it; do not create a duplicate. Complete the available app setup and record the exact App ID.

- [ ] **Step 3: Create or verify production ad units**

Create exactly one Banner unit and one Interstitial unit for the registered app, or reuse existing matching units. Record the exact IDs and make sure they are the IDs wired into the release build. If AdMob displays app verification, app-ads.txt, or review prerequisites, complete the available settings and record any external approval still pending.

- [ ] **Step 4: Create or verify the Play one-time product**

In the existing app's Monetize/Products area, create or reuse product ID `remove_ads` as a non-consumable/one-time product. Set the default price to US$4.99, add a clear title such as “Remove Ads”, add a description explaining that all in-game ads are removed, and activate the product. Do not change `gold_500`.

- [ ] **Step 5: Update Play declarations without publishing**

Set App content “Contains ads” to Yes. Review Data safety for the actual Google Mobile Ads SDK behavior and submit only the required declaration changes. Do not click Start rollout, Publish, or any Production release control.

- [ ] **Step 6: Record the exact IDs for the Android wiring task**

Keep the exact App ID, banner unit ID, and interstitial unit ID ready for Task 10. The repository remains unchanged until the identifiers are verified against the correct AdMob app. Keep a note of the external status: configured, under review, or blocked by a Google prerequisite.

- [ ] **Step 7: Leave browser cleanup until all external work is complete**

Keep the Play Console and AdMob pages needed for the user's handoff open until Task 12; the Chrome cleanup action is the final browser operation after the testing-track upload.

### Task 10: Configure Android release resources for real AdMob IDs

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/android/app/src/main/res/values/admob.xml`
- Modify: `app/android/app/build.gradle.kts`
- Modify: `app/lib/services/ad_config.dart`
- Test: `app/test/ad_config_test.dart`

**Interfaces:**
- Consumes: the exact App ID, banner unit ID, and interstitial unit ID returned by the AdMob account in Task 9.
- Produces: a release AAB that uses production IDs and a debug/test mode that uses Google's official test units.

- [ ] **Step 1: Write the configuration validation test**

Add a Dart test that asserts release configuration is not empty and follows the AdMob ID shapes:

```dart
test('release AdMob configuration is populated', () {
  expect(AdMobConfig.productionAppId, startsWith('ca-app-pub-'));
  expect(AdMobConfig.productionBannerUnitId, startsWith('ca-app-pub-'));
  expect(AdMobConfig.productionInterstitialUnitId, startsWith('ca-app-pub-'));
});
```

- [ ] **Step 2: Run it before wiring the external IDs**

Run:

```powershell
flutter test test/ad_config_test.dart
```

Expected: FAIL because the production IDs have not been wired yet.

- [ ] **Step 3: Add the Android manifest metadata and public resource**

Add the Google Mobile Ads application metadata to the `<application>` element:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="@string/admob_app_id" />
```

Create `res/values/admob.xml` with the exact production App ID returned by AdMob. Keep it as a public identifier, not a secret. The Kotlin/Gradle file must fail the release build when this resource is missing rather than silently using an empty fallback.

- [ ] **Step 4: Wire production and debug unit selection**

Store the exact production unit IDs in `AdMobConfig`, use official Google test unit IDs when `kDebugMode` or `ADMOB_USE_TEST_ADS=true`, and use production unit IDs for every release AAB including Closed Testing. Do not log IDs or receipt tokens in user-facing error messages.

- [ ] **Step 5: Run configuration, analyzer, and Android packaging checks**

Run:

```powershell
flutter test test/ad_config_test.dart
flutter analyze
```

Expected: PASS with no Android manifest/resource errors.

- [ ] **Step 6: Commit the release AdMob configuration**

```powershell
git add app/android/app/src/main/AndroidManifest.xml app/android/app/src/main/res/values/admob.xml app/android/app/build.gradle.kts app/lib/services/ad_config.dart app/test/ad_config_test.dart
git commit -m "build: configure production AdMob identifiers"
```

### Task 11: Deploy the backend changes safely

**Files:**
- Deploy: `supabase/migrations/20260820140000_remove_ads_entitlement.sql`
- Deploy: `supabase/functions/verify-purchase/index.ts`
- Deploy: `supabase/functions/sync-voided-purchases/index.ts`

**Interfaces:**
- Consumes: Supabase project ref `vqssjwewtjgekuyzzggo`, existing Google service-account secret, existing Android package secret, and the tested migration/function source.
- Produces: remote ledger schema and functions ready before the new client reaches testers.

- [ ] **Step 1: Check the Supabase CLI and remote project context**

Run:

```powershell
supabase --help
supabase projects list
```

Confirm the target is project ref `vqssjwewtjgekuyzzggo`; do not link or push to another project.

- [ ] **Step 2: Apply the migration**

Run:

```powershell
supabase db push --project-ref vqssjwewtjgekuyzzggo
```

Expected: the new column, constraint, index, and helper function apply without rewriting existing purchases.

- [ ] **Step 3: Deploy both Edge Functions**

Run:

```powershell
supabase functions deploy verify-purchase --project-ref vqssjwewtjgekuyzzggo
supabase functions deploy sync-voided-purchases --project-ref vqssjwewtjgekuyzzggo
```

Verify required secrets remain configured; never print their values. If a secret is missing, stop the client upload and report the exact secret name only.

- [ ] **Step 4: Run a read-only smoke query and function contract check**

Confirm the `purchased_remove_ads()` function exists and that the authenticated owner can select their purchase rows while anonymous/client inserts remain denied. Do not create a real purchase during smoke testing.

- [ ] **Step 5: Commit any deployment-only source corrections**

```powershell
git status --short
git add supabase
git commit -m "chore: deploy remove ads entitlement backend"
```

### Task 12: Build and offer the new AAB only through testing

**Files:**
- Modify: `app/pubspec.yaml` version/build number after checking Play's latest uploaded version.
- Generate: `app/build/app/outputs/bundle/release/app-release.aab`

**Interfaces:**
- Consumes: green app/backend tests, production AdMob configuration, active Play product, and release signing configuration.
- Produces: a versioned release AAB uploaded to the existing Internal or Closed Testing track, never Production.

- [ ] **Step 1: Select a unique version code**

Read the latest uploaded Play version code from the Console and the current `pubspec.yaml`. Set the Flutter build number to the next unused integer, preserving the existing version name unless Play requires a higher semantic version.

- [ ] **Step 2: Run the full verification suite**

From `app` run:

```powershell
flutter pub get
flutter test
flutter analyze
```

Expected: all tests PASS, analyzer has no errors, and all production AdMob IDs/configuration tests pass.

- [ ] **Step 3: Build the signed release bundle**

Run:

```powershell
flutter build appbundle --release
```

Verify the output exists, the signing config is release signing rather than the debug fallback, and the manifest contains `com.google.android.gms.ads.APPLICATION_ID`.

- [ ] **Step 4: Upload to the existing testing track**

In Play Console upload only to the existing Internal/Closed Testing track. Add release notes mentioning AdMob monetization and Remove Ads. Confirm the destination track before submission and do not open the Production release flow.

- [ ] **Step 5: Verify the testing artifact and product visibility**

Confirm the tester-eligible artifact is the new version code, `remove_ads` appears as an available test product at the localized price, “Contains ads” is enabled, and the release is not in Production.

- [ ] **Step 6: Finalize the Chrome handoff**

Keep the Play Console release/product page and AdMob app/units page needed by the user with `status: "deliverable"` or `status: "handoff"`, then call `chrome.tabs.finalize({keep: [...]})`. This must be the final Chrome action; do not navigate or inspect a tab after finalization.

- [ ] **Step 7: Commit the version bump and final source state**

```powershell
git add app/pubspec.yaml
git commit -m "release: prepare monetization build for testing"
```

### Task 13: Final verification and handoff

**Files:**
- Verify: all changed source/tests/docs listed by `git status`.
- Verify: `docs/superpowers/specs/2026-08-20-ads-remove-ads-design.md` and this plan.

**Interfaces:**
- Consumes: the test-track release and external console state.
- Produces: an evidence-backed handoff stating what is live in testing, what is production-ready, and any Google approval still pending.

- [ ] **Step 1: Run fresh final checks after the upload**

Run:

```powershell
git status --short --branch
flutter test
flutter analyze
```

Expected: PASS with no untracked secrets, generated credentials, or accidental unrelated edits.

- [ ] **Step 2: Verify the production-readiness contract**

Check that the release source uses the real AdMob App ID/unit IDs, the debug switch uses test units, `remove_ads` is active at US$4.99, the backend functions are deployed, and no Production release was started.

- [ ] **Step 3: Verify the ad safety contract**

Confirm banners exist only on main menu/Collection/Booster, interstitial calls exist only after local Duel/Story/Arena result flows, and no ad service is passed into PvP or active battle screens.

- [ ] **Step 4: Report the handoff**

Include the testing track/version code, AdMob app/unit setup status, Play product status, backend deployment status, test/build results, and the exact owner action remaining: start or publish Production only after Google approvals and the owner's explicit decision.
