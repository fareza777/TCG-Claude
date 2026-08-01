# Shardfall Gold Purchase and Play Billing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add a Google Play consumable product gold_500 that grants 500 Gold for US$1.00, expose it in the Booster screen, prepare a signed closed-test build, push the code, and publish the existing YouTube trailer.

**Architecture:** Keep the existing offline SaveService as the local game economy and add a focused GoldPurchaseService that wraps Flutter's official in_app_purchase API. The service owns store availability, localized product details, purchase-stream handling, idempotent delivery, and UI state; MenuScreen owns its lifecycle and injects it into BoosterScreen.

**Tech Stack:** Flutter/Dart, in_app_purchase: ^3.3.0, SharedPreferences, Google Play one-time consumable products, Android release AAB, Play Console browser flow, YouTube Studio.

## Global Constraints

- Product ID is exactly gold_500.
- A successful purchase grants exactly 500 Gold.
- The base price is exactly US$1.00; Play may display a localized equivalent.
- The product is consumable and must be completed/consumed after delivery so it can be purchased again.
- Only Android/Google Play billing is enabled in this iteration; other platforms keep the game playable and show purchasing as unavailable.
- No purchase is granted for pending, canceled, errored, or unknown-product events.
- No server-side receipt verification is added in this iteration because the existing game has no account/backend system; this remains a pre-production hardening item.
- The existing pack cost remains 100 Gold.
- The new AAB is uploaded to Closed testing as a release draft; do not submit production access or production rollout.
- The existing YouTube URL remains https://youtu.be/odO1Ks-SkW8 and is changed to Public only after the upload is complete.
- Preserve unrelated working-tree changes, especially app/android/app/build.gradle.kts and store-assets/; stage only files belonging to this feature and the intended release metadata.

## File Map

- Create: app/lib/services/purchase_catalog.dart — canonical product ID and Gold grant constants.
- Create: app/lib/services/gold_purchase_service.dart — Flutter Play Billing adapter, purchase lifecycle, UI state, and idempotent delivery orchestration.
- Modify: app/lib/services/save_service.dart — persist processed purchase identifiers and grant a valid purchased product exactly once.
- Modify: app/lib/main.dart — create, initialize, listen to, inject, and dispose GoldPurchaseService.
- Modify: app/lib/packs/booster_screen.dart — add the Buy Gold panel and connect the action to the service.
- Modify: app/pubspec.yaml — add the official in_app_purchase dependency and increment the Android version to 0.1.1+2.
- Generate: app/pubspec.lock — update through flutter pub get; do not hand-edit it.
- Create: app/test/save_service_purchase_test.dart — test Gold delivery and duplicate protection.
- Create: app/test/gold_purchase_service_test.dart — test catalog/service mapping that does not require a live Play Store.
- Approved design: docs/superpowers/specs/2026-08-01-gold-purchase-and-play-billing-design.md.

---

### Task 1: Add the purchase catalog and idempotent SaveService delivery

**Files:**
- Create: app/lib/services/purchase_catalog.dart
- Modify: app/lib/services/save_service.dart around the fields, load, and _persist methods
- Create: app/test/save_service_purchase_test.dart

**Interfaces:**
- Produces PurchaseCatalog.gold500Id, PurchaseCatalog.gold500Amount, and PurchaseCatalog.productIds for the billing service and UI.
- Produces SaveService.grantPurchasedGold({required String productId, required String purchaseId}) -> Future<bool> for the billing service.

- [ ] **Step 1: Write the failing SaveService tests**

Create app/test/save_service_purchase_test.dart with these cases:

~~~dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../lib/services/purchase_catalog.dart';
import '../lib/services/save_service.dart';

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({'gold': SaveService.startGold});
  });

  test('grants 500 Gold once for a valid product', () async {
    final save = await SaveService.load(emptyLibrary);

    final first = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'purchase-token-1',
    );
    final duplicate = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'purchase-token-1',
    );

    expect(first, isTrue);
    expect(duplicate, isFalse);
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
  });

  test('rejects an unknown product and empty purchase id', () async {
    final save = await SaveService.load(emptyLibrary);

    expect(
      await save.grantPurchasedGold(
        productId: 'unknown_product',
        purchaseId: 'purchase-token-2',
      ),
      isFalse,
    );
    expect(
      await save.grantPurchasedGold(
        productId: PurchaseCatalog.gold500Id,
        purchaseId: '  ',
      ),
      isFalse,
    );
    expect(save.gold, SaveService.startGold);
  });

  test('restores processed purchase ids after reload', () async {
    final firstSave = await SaveService.load(emptyLibrary);
    await firstSave.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'purchase-token-3',
    );

    final reloaded = await SaveService.load(emptyLibrary);
    expect(
      await reloaded.grantPurchasedGold(
        productId: PurchaseCatalog.gold500Id,
        purchaseId: 'purchase-token-3',
      ),
      isFalse,
    );
    expect(
      reloaded.gold,
      SaveService.startGold + PurchaseCatalog.gold500Amount,
    );
  });
}
~~~

- [ ] **Step 2: Run the focused test to verify it fails**

Run from C:\TCG Claude\app:

~~~powershell
flutter test test/save_service_purchase_test.dart
~~~

Expected: FAIL because PurchaseCatalog and grantPurchasedGold do not exist yet.

- [ ] **Step 3: Add the canonical purchase constants**

Create app/lib/services/purchase_catalog.dart:

~~~dart
abstract final class PurchaseCatalog {
  static const gold500Id = 'gold_500';
  static const gold500Amount = 500;
  static const productIds = <String>{gold500Id};
}
~~~

- [ ] **Step 4: Implement idempotent Gold delivery**

In SaveService, add:

~~~dart
final Set<String> processedPurchaseIds = {};

Future<bool> grantPurchasedGold({
  required String productId,
  required String purchaseId,
}) async {
  final normalizedId = purchaseId.trim();
  if (productId != PurchaseCatalog.gold500Id ||
      normalizedId.isEmpty ||
      processedPurchaseIds.contains(normalizedId)) {
    return false;
  }
  gold += PurchaseCatalog.gold500Amount;
  processedPurchaseIds.add(normalizedId);
  await _persist();
  notifyListeners();
  return true;
}
~~~

Import purchase_catalog.dart, load processedPurchaseIds from the processedPurchaseIds SharedPreferences string list, and persist it in _persist() with setStringList.

- [ ] **Step 5: Run the focused test to verify it passes**

Run:

~~~powershell
flutter test test/save_service_purchase_test.dart
~~~

Expected: PASS for all three cases.

- [ ] **Step 6: Commit the local economy boundary**

~~~powershell
git add -- app/lib/services/purchase_catalog.dart app/lib/services/save_service.dart app/test/save_service_purchase_test.dart
git commit -m "feat: add idempotent purchased Gold delivery"
~~~

---

### Task 2: Add the Play Billing service and non-store service tests

**Files:**
- Modify: app/pubspec.yaml
- Generate: app/pubspec.lock
- Create: app/lib/services/gold_purchase_service.dart
- Create: app/test/gold_purchase_service_test.dart

**Interfaces:**
- Consumes PurchaseCatalog and SaveService.grantPurchasedGold from Task 1.
- Produces GoldPurchaseState, GoldPurchaseService.product, GoldPurchaseService.priceLabel, GoldPurchaseService.canBuy, GoldPurchaseService.message, GoldPurchaseService.initialize(), and GoldPurchaseService.buyGold() for the UI.

- [ ] **Step 1: Add the official dependency and fetch packages**

Modify app/pubspec.yaml under dependencies:

~~~yaml
  in_app_purchase: ^3.3.0
~~~

Run from C:\TCG Claude\app:

~~~powershell
flutter pub get
~~~

Expected: pubspec.lock records in_app_purchase and its platform packages without manual edits.

- [ ] **Step 2: Write non-store tests for the service contract**

Create app/test/gold_purchase_service_test.dart to verify the public catalog contract without opening Play Billing:

~~~dart
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/purchase_catalog.dart';

void main() {
  test('exposes the closed-test Play product catalog', () {
    expect(PurchaseCatalog.gold500Id, 'gold_500');
    expect(PurchaseCatalog.gold500Amount, 500);
    expect(PurchaseCatalog.productIds, contains('gold_500'));
  });
}
~~~

- [ ] **Step 3: Implement the store adapter and state model**

Create app/lib/services/gold_purchase_service.dart with these public types and signatures:

~~~dart
enum GoldPurchaseState {
  loading,
  ready,
  unavailable,
  purchasing,
  pending,
  success,
  error,
}

abstract interface class GoldStore {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
}

class FlutterGoldStore implements GoldStore {
  FlutterGoldStore({InAppPurchase? instance})
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _instance.queryProductDetails(identifiers);

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) =>
      _instance.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _instance.completePurchase(purchase);
}
~~~

Define GoldPurchaseService extends ChangeNotifier with SaveService save, optional GoldStore store, and this public surface:

~~~dart
class GoldPurchaseService extends ChangeNotifier {
  GoldPurchaseService({required this.save, GoldStore? store})
      : store = store ?? FlutterGoldStore();

  final SaveService save;
  final GoldStore store;

  GoldPurchaseState state = GoldPurchaseState.loading;
  ProductDetails? product;
  String? message;

  bool get canBuy => state == GoldPurchaseState.ready && product != null;
  String get priceLabel => product?.price ?? 'Price unavailable';

  Future<void> initialize();
  Future<void> buyGold();
}
~~~

Subscribe to purchaseStream before querying products. On Android, call isAvailable, query PurchaseCatalog.productIds, select exactly gold_500, and set ready only when a product exists. For web, Windows, and other non-Android targets, set unavailable with a clear message. Catch store/query exceptions and set error without throwing into the game UI.

- [ ] **Step 4: Implement the purchase update lifecycle**

Handle each PurchaseDetails as follows:

~~~text
productID != gold_500  -> ignore
pending                -> state=pending; no Gold; no completion
canceled               -> state=error; no Gold
error                  -> state=error; no Gold
purchased              -> derive purchase id; grant once; complete if pendingCompletePurchase
restored               -> do not grant a consumable again
~~~

Derive a non-empty local id from purchase.purchaseID, falling back to purchase.verificationData.serverVerificationData. For a purchased event, call save.grantPurchasedGold(productId: purchase.productID, purchaseId: derivedId). Set success when it returns true, return to ready when it reports a duplicate, and always call completePurchase after delivery when pendingCompletePurchase is true. Reset the purchasing flag for terminal states. Expose messages such as 500 Gold added to your balance., Payment is pending confirmation from Google Play., and Purchase canceled.

Keep the stream subscription in the service and cancel it in dispose().

- [ ] **Step 5: Run the service contract test and static analysis**

Run from C:\TCG Claude\app:

~~~powershell
flutter test test/gold_purchase_service_test.dart
flutter analyze
~~~

Expected: the contract test passes and the new service has no analyzer errors.

- [ ] **Step 6: Commit the billing service**

~~~powershell
git add -- app/pubspec.yaml app/pubspec.lock app/lib/services/gold_purchase_service.dart app/test/gold_purchase_service_test.dart
git commit -m "feat: add Google Play Gold purchase service"
~~~

---

### Task 3: Wire the service into the app and Booster UI

**Files:**
- Modify: app/lib/main.dart in _MenuScreenState lifecycle and Booster route construction
- Modify: app/lib/packs/booster_screen.dart constructor, imports, sealed-pack layout, and Buy Gold panel

**Interfaces:**
- Consumes GoldPurchaseService from Task 2.
- Produces a working BUY GOLD action without changing the existing buyPack or pack-opening logic.

- [ ] **Step 1: Add service ownership to MenuScreen**

Add GoldPurchaseService? _purchases to _MenuScreenState. After SaveService.load completes, construct GoldPurchaseService(save: save), attach the same mounted setState listener pattern used for SaveService, assign it in the existing setState, and start initialize() without blocking the first menu frame. Dispose it from _MenuScreenState.dispose().

Pass it into the Booster route:

~~~dart
builder: (_) => BoosterScreen(
  library: _library!,
  save: _save!,
  purchaseService: _purchases!,
),
~~~

- [ ] **Step 2: Make the BoosterScreen dependency explicit**

Add:

~~~dart
final GoldPurchaseService purchaseService;

const BoosterScreen({
  super.key,
  required this.library,
  required this.save,
  required this.purchaseService,
});
~~~

Import ../services/gold_purchase_service.dart and purchase_catalog.dart only where the UI needs the amount or price label.

- [ ] **Step 3: Add the sealed-state Buy Gold panel**

Keep the pack artwork and tap-to-open flow intact. Change only the sealed state layout to a scrollable column that contains the current pack interaction followed by a panel with:

~~~text
BUY GOLD
500 Gold · <localized ProductDetails.price>
Buy Gold
~~~

Wrap the panel with ListenableBuilder(listenable: widget.purchaseService, ...). The button is enabled only when purchaseService.canBuy; otherwise show loading or unavailable copy. Call purchaseService.buyGold on tap. Render purchaseService.message below the button with the existing muted/gold color system. Do not show a hard-coded US$1.00 as a confirmed price when Play has not returned product details.

- [ ] **Step 4: Run UI compilation and existing tests**

Run:

~~~powershell
flutter analyze
flutter test
~~~

Expected: all existing tests and the two new purchase tests pass, with no constructor call sites left without purchaseService.

- [ ] **Step 5: Commit the UI integration**

~~~powershell
git add -- app/lib/main.dart app/lib/packs/booster_screen.dart
git commit -m "feat: add Buy Gold panel to Shard Packs"
~~~

---

### Task 4: Increment version and build the release AAB

**Files:**
- Modify: app/pubspec.yaml version from 0.1.0+1 to 0.1.1+2
- Generate: app/pubspec.lock only through Flutter tooling
- Output: app/build/app/outputs/bundle/release/app-release.aab

**Interfaces:**
- Consumes the completed app from Tasks 1–3.
- Produces version name 0.1.1, version code 2, and a release-signed AAB compatible with the existing Play app signing/upload key.

- [ ] **Step 1: Update the app version**

Modify app/pubspec.yaml:

~~~yaml
version: 0.1.1+2
~~~

- [ ] **Step 2: Run the complete automated checks**

From C:\TCG Claude\app:

~~~powershell
flutter pub get
flutter analyze
flutter test
~~~

Expected: all checks pass before producing the release artifact.

- [ ] **Step 3: Build the release bundle**

~~~powershell
flutter build appbundle --release
~~~

Expected: app\build\app\outputs\bundle\release\app-release.aab exists and is larger than zero bytes. Do not replace or commit the local keystore.

- [ ] **Step 4: Verify release metadata and working tree scope**

~~~powershell
Get-Item 'build\app\outputs\bundle\release\app-release.aab' | Select-Object FullName,Length,LastWriteTime
git status --short
~~~

Confirm the version is 0.1.1 (2) in the build output/Play upload dialog and that unrelated signing/assets changes remain unstaged.

- [ ] **Step 5: Commit the version bump**

~~~powershell
git add -- app/pubspec.yaml
git commit -m "chore: bump Shardfall for Gold billing test"
~~~

---

### Task 5: Configure gold_500 and upload the closed-test release in Play Console

**Files:**
- No repository files; browser state in the user's Play Console session
- Artifact: C:\TCG Claude\app\build\app\outputs\bundle\release\app-release.aab

**Interfaces:**
- Consumes the product ID, copy, and price from the Global Constraints.
- Produces an active Play product and a closed-test release draft containing version 0.1.1 (2).

- [ ] **Step 1: Open the app's monetization/product catalog**

Use the Play Console app Shardfall: The Sundering under developer account 7590575640597683388. Navigate through the current UI under Monetize with Play to the one-time/in-app product catalog. Do not use the subscription flow.

- [ ] **Step 2: Create the one-time product**

Enter exactly:

~~~text
Product ID: gold_500
Name: 500 Gold
Description: Add 500 Gold to your Shardfall balance for opening Shard Packs.
Base price: US$1.00
~~~

Save and activate the product. If Play requires a merchant, tax, identity, bank, or payments profile before activation, stop at that exact blocker and report the required account action instead of activating a different product or price.

- [ ] **Step 3: Open the existing Closed testing track**

Use the existing Alpha/closed-testing track for app ID 4975336496530171100, keep the copied Vocatim tester groups unchanged, and create a new release draft. Upload the release-signed AAB from Task 4. Use:

~~~text
Release name: 0.1.1 - Gold purchase test
Release notes: Add optional Google Play billing for 500 Gold and improve the Shard Pack purchase flow.
~~~

Save the release as a draft. Do not press Send for review, Start rollout, or any production action.

- [ ] **Step 4: Verify the Console state**

Confirm the product is active, the price is US$1.00, the release shows version 0.1.1 (2), the AAB upload completed, and the closed-test release is ready for the user's next action. Keep the Play Console release tab open for handoff.

---

### Task 6: Make the YouTube trailer Public

**Files:**
- No repository files; browser state in YouTube Studio

**Interfaces:**
- Consumes the existing video https://youtu.be/odO1Ks-SkW8.
- Produces the same video URL with visibility Public.

- [ ] **Step 1: Open the existing YouTube Studio video detail**

Use the already authenticated YouTube Studio session for the Shardfall trailer. Verify the title is SHARDFALL: The Sundering | Official Gameplay Trailer before changing visibility.

- [ ] **Step 2: Change visibility to Public**

Select Public, save/publish the visibility change, and confirm the published result. If YouTube still shows an in-progress policy check, use the explicit publish confirmation only for this already-uploaded game trailer; do not create a duplicate upload.

- [ ] **Step 3: Verify the public link**

Confirm https://youtu.be/odO1Ks-SkW8 remains the video URL and that YouTube shows Public. Keep the video detail tab open for handoff.

---

### Task 7: Final verification, commit, and push

**Files:**
- Repository files from Tasks 1–4 only
- Do not stage app/android/app/build.gradle.kts or store-assets/ unless they were already intentionally part of the user's changes and separately approved

- [ ] **Step 1: Run final local checks**

From C:\TCG Claude\app:

~~~powershell
flutter analyze
flutter test
flutter build appbundle --release
~~~

Expected: all checks pass and the release AAB is regenerated successfully.

- [ ] **Step 2: Review the exact diff and stage only feature files**

From C:\TCG Claude:

~~~powershell
git diff --check
git status --short
git diff -- app/pubspec.yaml app/lib/services/purchase_catalog.dart app/lib/services/gold_purchase_service.dart app/lib/services/save_service.dart app/lib/main.dart app/lib/packs/booster_screen.dart app/test/save_service_purchase_test.dart app/test/gold_purchase_service_test.dart
git add -- app/pubspec.yaml app/lib/services/purchase_catalog.dart app/lib/services/gold_purchase_service.dart app/lib/services/save_service.dart app/lib/main.dart app/lib/packs/booster_screen.dart app/test/save_service_purchase_test.dart app/test/gold_purchase_service_test.dart
~~~

Expected: only the intended billing/version files are staged; signing configuration and generated store assets remain untouched.

- [ ] **Step 3: Commit the implementation**

~~~powershell
git commit -m "feat: add Google Play Gold purchases"
~~~

- [ ] **Step 4: Push the completed history**

~~~powershell
git push origin main
~~~

Expected: main on origin contains the approved design, implementation, tests, and version bump.

- [ ] **Step 5: Final handoff**

Report the active product state, closed-test release draft state, public YouTube URL, local AAB path, test results, and any Play payments-profile blocker. Leave the Play Console closed-test tab and public YouTube video tab open.

## Plan Self-Review

- Spec coverage: product ID, price, consumable behavior, idempotency, UI states, Play Console catalog, closed-test AAB, YouTube visibility, error handling, automated tests, and production boundary each have an explicit task.
- Checklist scan: no incomplete or vague implementation-only steps remain.
- Type consistency: PurchaseCatalog is created in Task 1 and consumed by Tasks 2–3; SaveService.grantPurchasedGold is created in Task 1 and called by GoldPurchaseService in Task 2; GoldPurchaseService is injected by Task 3.
- Scope: repository changes are limited to the purchase service, local delivery idempotency, Booster UI, tests, dependency, and version metadata; payment setup and YouTube visibility are external handoff actions.
