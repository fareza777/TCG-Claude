import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/purchase_catalog.dart';
import 'package:shardfall/services/remove_ads_purchase_service.dart';
import 'package:shardfall/services/save_service.dart';

class _FakeRemoveAdsStore implements RemoveAdsStore {
  _FakeRemoveAdsStore({this.products = const <ProductDetails>[]});

  final List<ProductDetails> products;
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];

  int restoreCalls = 0;
  int buyCalls = 0;
  PurchaseParam? lastPurchaseParam;
  Object? restoreError;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    lastPurchaseParam = purchaseParam;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    final error = restoreError;
    if (error != null) throw error;
  }

  void emit(List<PurchaseDetails> purchases) => _purchases.add(purchases);

  Future<void> close() => _purchases.close();
}

PurchaseDetails _purchase({
  required String purchaseId,
  required PurchaseStatus status,
  String productId = PurchaseCatalog.removeAdsId,
}) {
  return PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$purchaseId',
      serverVerificationData: 'server-$purchaseId',
      source: 'google_play',
    ),
    transactionDate: '1754000000000',
    status: status,
  )..pendingCompletePurchase = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  final removeAdsProduct = ProductDetails(
    id: PurchaseCatalog.removeAdsId,
    title: 'Remove Ads',
    description: 'Remove all in-game advertisements.',
    price: '\$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );

  late _FakeRemoveAdsStore store;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
    });
    store = _FakeRemoveAdsStore(products: [removeAdsProduct]);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await store.close();
  });

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('loads the Remove Ads product and restores purchases', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);

    await service.initialize();

    expect(service.state, RemoveAdsPurchaseState.ready);
    expect(service.product, removeAdsProduct);
    expect(service.priceLabel, '\$4.99');
    expect(service.canBuy, isTrue);
    expect(store.restoreCalls, 1);
  });

  test('starts a non-consumable purchase with the product details', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);
    await service.initialize();

    await service.buyRemoveAds();

    expect(store.buyCalls, 1);
    expect(store.lastPurchaseParam?.productDetails, removeAdsProduct);
    expect(service.state, RemoveAdsPurchaseState.purchasing);
  });

  test('delivers a purchased token once and completes it', () async {
    final save = await SaveService.load(emptyLibrary);
    final seen = <String>[];
    final service = RemoveAdsPurchaseService(
      save: save,
      store: store,
      verifier: ({required productId, required purchaseToken}) async {
        seen.add('$productId|$purchaseToken');
        return true;
      },
    );
    await service.initialize();

    final purchase = _purchase(
      purchaseId: 'token-1',
      status: PurchaseStatus.purchased,
    );
    store.emit([purchase]);
    await settle();

    expect(save.removeAds, isTrue);
    expect(service.state, RemoveAdsPurchaseState.owned);
    expect(store.completed, contains(purchase));
    expect(seen, ['${PurchaseCatalog.removeAdsId}|server-token-1']);
    expect(save.unverifiedPurchases, isEmpty);
  });

  test('does not grant the same restored purchase twice', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'token-2', status: PurchaseStatus.purchased),
    ]);
    await settle();
    store.emit([
      _purchase(purchaseId: 'token-2', status: PurchaseStatus.restored),
    ]);
    await settle();

    expect(save.removeAds, isTrue);
    expect(save.removeAdsPurchaseIds, hasLength(2));
    expect(service.state, RemoveAdsPurchaseState.owned);
  });

  test(
    'keeps local ownership when backend verification is unavailable',
    () async {
      final save = await SaveService.load(emptyLibrary);
      final service = RemoveAdsPurchaseService(
        save: save,
        store: store,
        verifier: ({required productId, required purchaseToken}) async => false,
      );
      await service.initialize();

      store.emit([
        _purchase(purchaseId: 'token-3', status: PurchaseStatus.purchased),
      ]);
      await settle();

      expect(save.removeAds, isTrue);
      expect(
        save.unverifiedPurchases,
        contains('${PurchaseCatalog.removeAdsId}|server-token-3'),
      );
      expect(service.state, RemoveAdsPurchaseState.owned);
    },
  );

  test('handles pending and canceled states without granting access', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'pending', status: PurchaseStatus.pending),
    ]);
    await settle();
    expect(service.state, RemoveAdsPurchaseState.pending);
    expect(save.removeAds, isFalse);

    store.emit([
      _purchase(purchaseId: 'canceled', status: PurchaseStatus.canceled),
    ]);
    await settle();
    expect(service.state, RemoveAdsPurchaseState.ready);
    expect(save.removeAds, isFalse);
  });

  test('ignores Gold and unknown products', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);
    await service.initialize();

    store.emit([
      _purchase(
        purchaseId: 'gold-token',
        status: PurchaseStatus.restored,
        productId: PurchaseCatalog.gold500Id,
      ),
      _purchase(
        purchaseId: 'unknown-token',
        status: PurchaseStatus.restored,
        productId: 'unknown_product',
      ),
    ]);
    await settle();

    expect(save.removeAds, isFalse);
    expect(store.completed, isEmpty);
  });

  test('stays usable when restore fails', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = RemoveAdsPurchaseService(save: save, store: store);
    store.restoreError = StateError('billing unavailable');

    await service.initialize();

    expect(service.state, RemoveAdsPurchaseState.ready);
    expect(service.canBuy, isTrue);
  });
}
