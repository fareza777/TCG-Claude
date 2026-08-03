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

  test('treats the order id and the purchase token as one grant', () async {
    final save = await SaveService.load(emptyLibrary);

    // Play delivers first, keyed on the token with the order id alongside.
    final fromPlay = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-abc',
      aliasIds: {'order-abc'},
    );
    // A later backend restore knows only the token.
    final fromBackend = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-abc',
    );

    expect(fromPlay, isTrue);
    expect(fromBackend, isFalse);
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
  });

  test('recognises a grant first seen under its order id', () async {
    final save = await SaveService.load(emptyLibrary);

    // An install from before the token became the ledger key.
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'order-legacy',
    );
    final replay = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-legacy',
      aliasIds: {'order-legacy'},
    );

    expect(replay, isFalse);
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
    // The token is now known too, so a backend restore stays idempotent.
    expect(
      await save.grantPurchasedGold(
        productId: PurchaseCatalog.gold500Id,
        purchaseId: 'token-legacy',
      ),
      isFalse,
    );
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
  });

  test('queues a purchase for verification until the backend confirms',
      () async {
    final save = await SaveService.load(emptyLibrary);

    await save.markPurchaseUnverified('gold_500', 'token-pending');
    expect(save.unverifiedPurchases, contains('gold_500|token-pending'));

    final reloaded = await SaveService.load(emptyLibrary);
    expect(reloaded.unverifiedPurchases, contains('gold_500|token-pending'));

    await reloaded.markPurchaseVerified('gold_500', 'token-pending');
    expect(reloaded.unverifiedPurchases, isEmpty);
  });

  test('a refund takes the Gold back exactly once', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-refund',
    );

    final first = await save.revokePurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-refund',
    );
    final second = await save.revokePurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-refund',
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(save.gold, SaveService.startGold);
  });

  test('a refund cannot push the balance negative', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-spent',
    );
    // The player spent everything before the refund landed.
    await save.addGold(-save.gold);

    await save.revokePurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-spent',
    );

    expect(save.gold, 0);
  });

  test('a refunded purchase is never granted again by a restore', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-void',
    );
    await save.revokePurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-void',
    );

    final regranted = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-void',
    );

    expect(regranted, isFalse);
    expect(save.gold, SaveService.startGold);
  });

  test('a refund from another device blocks a first delivery here', () async {
    final save = await SaveService.load(emptyLibrary);

    // This device never delivered it; the backend already says refunded.
    await save.revokePurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-elsewhere',
    );
    final granted = await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-elsewhere',
    );

    expect(granted, isFalse);
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
