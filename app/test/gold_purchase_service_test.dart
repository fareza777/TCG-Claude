import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/gold_purchase_service.dart';
import 'package:shardfall/services/purchase_catalog.dart';
import 'package:shardfall/services/save_service.dart';

/// A [GoldStore] that never opens a real Play Billing sheet.
class _FakeGoldStore implements GoldStore {
  _FakeGoldStore({this.products = const <ProductDetails>[]});

  final List<ProductDetails> products;
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];

  int restoreCalls = 0;
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
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async =>
      true;

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
  String productId = PurchaseCatalog.gold500Id,
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

  final goldProduct = ProductDetails(
    id: PurchaseCatalog.gold500Id,
    title: '500 Gold',
    description: '500 Gold for Shard Packs.',
    price: 'Rp 15.000',
    rawPrice: 15000,
    currencyCode: 'IDR',
  );

  late _FakeGoldStore store;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
    });
    store = _FakeGoldStore(products: [goldProduct]);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await store.close();
  });

  /// Lets the unawaited purchase-stream handler finish before assertions.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('exposes the closed-test Play product catalog', () {
    expect(PurchaseCatalog.gold500Id, 'gold_500');
    expect(PurchaseCatalog.gold500Amount, 500);
    expect(PurchaseCatalog.productIds, contains('gold_500'));
  });

  test('queries unconsumed purchases once the catalog is ready', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(save: save, store: store);

    await service.initialize();

    expect(service.state, GoldPurchaseState.ready);
    expect(store.restoreCalls, 1);
  });

  test('stays usable when the restore query fails', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(save: save, store: store);
    store.restoreError = StateError('billing unavailable');

    await service.initialize();

    expect(service.state, GoldPurchaseState.ready);
    expect(service.canBuy, isTrue);
  });

  test('delivers Gold for a purchase that was never consumed', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(save: save, store: store);
    await service.initialize();

    final stranded = _purchase(
      purchaseId: 'stranded-token',
      status: PurchaseStatus.restored,
    );
    store.emit([stranded]);
    await settle();

    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
    expect(service.state, GoldPurchaseState.success);
    expect(store.completed, contains(stranded));
  });

  test('never grants the same purchase twice across a restore', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(save: save, store: store);
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'token-1', status: PurchaseStatus.purchased),
    ]);
    await settle();
    store.emit([
      _purchase(purchaseId: 'token-1', status: PurchaseStatus.restored),
    ]);
    await settle();

    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
  });

  test('records a delivered purchase with the backend', () async {
    final save = await SaveService.load(emptyLibrary);
    final seen = <String>[];
    final service = GoldPurchaseService(
      save: save,
      store: store,
      verifier: ({required productId, required purchaseToken}) async {
        seen.add('$productId|$purchaseToken');
        return true;
      },
    );
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'token-2', status: PurchaseStatus.purchased),
    ]);
    await settle();

    // The backend ledger is keyed on the token, not the order id.
    expect(seen, ['${PurchaseCatalog.gold500Id}|server-token-2']);
    expect(save.unverifiedPurchases, isEmpty);
  });

  test('keeps a purchase queued when the backend cannot record it', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(
      save: save,
      store: store,
      verifier: ({required productId, required purchaseToken}) async => false,
    );
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'token-3', status: PurchaseStatus.purchased),
    ]);
    await settle();

    // Gold is granted regardless — a backend outage never withholds it.
    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
    expect(service.state, GoldPurchaseState.success);
    expect(
      save.unverifiedPurchases,
      contains('${PurchaseCatalog.gold500Id}|server-token-3'),
    );
  });

  test('a failing verifier never costs the player their Gold', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(
      save: save,
      store: store,
      verifier: ({required productId, required purchaseToken}) async =>
          throw StateError('network down'),
    );
    await service.initialize();

    store.emit([
      _purchase(purchaseId: 'token-4', status: PurchaseStatus.purchased),
    ]);
    await settle();

    expect(save.gold, SaveService.startGold + PurchaseCatalog.gold500Amount);
    expect(
      save.unverifiedPurchases,
      contains('${PurchaseCatalog.gold500Id}|server-token-4'),
    );
  });

  test('ignores restored purchases for other products', () async {
    final save = await SaveService.load(emptyLibrary);
    final service = GoldPurchaseService(save: save, store: store);
    await service.initialize();

    store.emit([
      _purchase(
        purchaseId: 'other-token',
        status: PurchaseStatus.restored,
        productId: 'some_other_product',
      ),
    ]);
    await settle();

    expect(save.gold, SaveService.startGold);
    expect(store.completed, isEmpty);
  });
}
