import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/services/purchase_catalog.dart';
import 'package:shardfall/services/save_service.dart';

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
    });
  });

  Map<String, dynamic> overTheWire(Map<String, dynamic> snapshot) =>
      json.decode(json.encode(snapshot)) as Map<String, dynamic>;

  test('catalog exposes a non-consumable remove ads product', () {
    expect(PurchaseCatalog.removeAdsId, 'remove_ads');
    expect(PurchaseCatalog.productIds, contains('remove_ads'));
    expect(PurchaseCatalog.gold500Amount, 500);
  });

  test('grants remove ads once and persists it', () async {
    final save = await SaveService.load(emptyLibrary);

    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'remove-token-1',
      ),
      isTrue,
    );
    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'remove-token-1',
      ),
      isFalse,
    );
    expect(save.removeAds, isTrue);

    final reloaded = await SaveService.load(emptyLibrary);
    expect(reloaded.removeAds, isTrue);
    expect(reloaded.removeAdsPurchaseIds, contains('remove-token-1'));
  });

  test('treats the order id and token as one remove ads grant', () async {
    final save = await SaveService.load(emptyLibrary);

    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'token-abc',
        aliasIds: {'order-abc'},
      ),
      isTrue,
    );
    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'order-abc',
        aliasIds: {'token-abc'},
      ),
      isFalse,
    );
    expect(save.removeAdsPurchaseIds, containsAll(['token-abc', 'order-abc']));
  });

  test('revoking one entitlement token does not revoke another active token',
      () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantRemoveAds(
      productId: PurchaseCatalog.removeAdsId,
      purchaseId: 'token-a',
    );
    await save.grantRemoveAds(
      productId: PurchaseCatalog.removeAdsId,
      purchaseId: 'token-b',
    );

    expect(
      await save.revokeRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'token-a',
      ),
      isTrue,
    );
    expect(save.removeAds, isTrue);
    expect(
      await save.revokeRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'token-b',
      ),
      isTrue,
    );
    expect(save.removeAds, isFalse);
  });

  test('a refund blocks a later restore of the same token', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.revokeRemoveAds(
      productId: PurchaseCatalog.removeAdsId,
      purchaseId: 'token-refunded',
    );

    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: 'token-refunded',
      ),
      isFalse,
    );
    expect(save.removeAds, isFalse);
  });

  test('snapshot round-trips the entitlement and old snapshots keep it',
      () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantRemoveAds(
      productId: PurchaseCatalog.removeAdsId,
      purchaseId: 'token-snapshot',
    );

    final snapshot = overTheWire(save.toSnapshot());
    SharedPreferences.setMockInitialValues({});
    final restored = await SaveService.load(emptyLibrary);
    await restored.applySnapshot(snapshot);

    expect(restored.removeAds, isTrue);
    expect(restored.removeAdsPurchaseIds, contains('token-snapshot'));

    await restored.applySnapshot(
      overTheWire({'gold': restored.gold, 'owned': <String, int>{}}),
    );
    expect(restored.removeAds, isTrue);
  });

  test('rejects unknown products and empty identifiers', () async {
    final save = await SaveService.load(emptyLibrary);

    expect(
      await save.grantRemoveAds(
        productId: 'gold_500',
        purchaseId: 'token-wrong-product',
      ),
      isFalse,
    );
    expect(
      await save.grantRemoveAds(
        productId: PurchaseCatalog.removeAdsId,
        purchaseId: '  ',
      ),
      isFalse,
    );
    expect(save.removeAds, isFalse);
  });
}
