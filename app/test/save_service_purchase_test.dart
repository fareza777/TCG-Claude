import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../lib/services/purchase_catalog.dart';
import '../lib/services/save_service.dart';

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': todayKey,
    });
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
