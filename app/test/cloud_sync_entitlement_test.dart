import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/services/auth_service.dart';
import 'package:shardfall/services/cloud_sync_service.dart';
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

  Future<CloudSyncService> cloudFor(SaveService save) async {
    return CloudSyncService(save: save, auth: AuthService());
  }

  test('restores an active Remove Ads entitlement idempotently', () async {
    final save = await SaveService.load(emptyLibrary);
    final cloud = await cloudFor(save);
    final row = {
      'product_id': PurchaseCatalog.removeAdsId,
      'purchase_token': 'remove-token-1',
      'order_id': 'order-1',
      'state': 'granted',
      'entitlement_id': PurchaseCatalog.removeAdsId,
    };

    expect(await cloud.applyPurchaseRows([row, row]), 0);
    expect(save.removeAds, isTrue);
    expect(
      save.removeAdsPurchaseIds,
      containsAll(['remove-token-1', 'order-1']),
    );
  });

  test(
    'a refunded Remove Ads row revokes only its own active identifiers',
    () async {
      final save = await SaveService.load(emptyLibrary);
      final cloud = await cloudFor(save);

      await cloud.applyPurchaseRows([
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-a',
          'order_id': 'order-a',
          'state': 'granted',
        },
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-b',
          'order_id': 'order-b',
          'state': 'granted',
        },
      ]);

      await cloud.applyPurchaseRows([
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-a',
          'order_id': 'order-a',
          'state': 'refunded',
        },
      ]);
      expect(save.removeAds, isTrue);

      await cloud.applyPurchaseRows([
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-b',
          'order_id': 'order-b',
          'state': 'refunded',
        },
      ]);
      expect(save.removeAds, isFalse);
    },
  );

  test('restores Gold separately and reports only new Gold grants', () async {
    final save = await SaveService.load(emptyLibrary);
    final cloud = await cloudFor(save);

    final granted = await cloud.applyPurchaseRows([
      {
        'product_id': PurchaseCatalog.gold500Id,
        'purchase_token': 'gold-token-1',
        'order_id': 'gold-order-1',
        'state': 'granted',
      },
      {
        'product_id': PurchaseCatalog.removeAdsId,
        'purchase_token': 'remove-token-1',
        'order_id': 'remove-order-1',
        'state': 'granted',
      },
      {
        'product_id': 'unknown_product',
        'purchase_token': 'unknown-token',
        'order_id': 'unknown-order',
        'state': 'granted',
      },
    ]);

    expect(granted, 1);
    expect(cloud.recoveredGold, PurchaseCatalog.gold500Amount);
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
    expect(save.removeAds, isTrue);
  });

  test(
    'a refunded row that was never delivered remains blocked locally',
    () async {
      final save = await SaveService.load(emptyLibrary);
      final cloud = await cloudFor(save);

      await cloud.applyPurchaseRows([
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-refunded',
          'order_id': 'remove-order-refunded',
          'state': 'refunded',
        },
        {
          'product_id': PurchaseCatalog.removeAdsId,
          'purchase_token': 'remove-token-refunded',
          'order_id': 'remove-order-refunded',
          'state': 'granted',
        },
      ]);

      expect(save.removeAds, isFalse);
    },
  );
}
