import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_catalog.dart';
import 'save_service.dart';

/// The UI-facing state of the Google Play Gold purchase flow.
enum GoldPurchaseState {
  loading,
  ready,
  unavailable,
  purchasing,
  pending,
  success,
  error,
}

/// Small adapter around the store API so the purchase flow can be tested
/// without opening a real Google Play billing sheet.
abstract interface class GoldStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyConsumable({required PurchaseParam purchaseParam});

  Future<void> completePurchase(PurchaseDetails purchase);
}

/// Production adapter for the Flutter in-app purchase plugin.
class FlutterGoldStore implements GoldStore {
  FlutterGoldStore({InAppPurchase? instance})
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) {
    return _instance.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) {
    return _instance.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _instance.completePurchase(purchase);
  }
}

/// Loads the Gold product and delivers completed purchases to [SaveService].
///
/// This iteration targets Google Play on Android. The local purchase ID ledger
/// in [SaveService] makes repeated purchase-stream deliveries idempotent while
/// the app is in closed testing; production server-side verification remains a
/// separate hardening step.
class GoldPurchaseService extends ChangeNotifier {
  GoldPurchaseService({
    required this.save,
    GoldStore? store,
  }) : store = store ?? FlutterGoldStore();

  final SaveService save;
  final GoldStore store;

  GoldPurchaseState state = GoldPurchaseState.loading;
  ProductDetails? product;
  String? message;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _initialized = false;

  bool get canBuy =>
      product != null &&
      (state == GoldPurchaseState.ready ||
          state == GoldPurchaseState.success ||
          state == GoldPurchaseState.error);

  String get priceLabel => product?.price ?? 'Price unavailable';

  /// Subscribe before querying the catalog so a store update cannot be missed.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _purchaseSubscription = store.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchases(purchases)),
      onError: (Object error, StackTrace stackTrace) {
        state = GoldPurchaseState.error;
        message = 'Google Play billing encountered an error.';
        notifyListeners();
      },
    );

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _setUnavailable('Gold purchases are available on Android only.');
      return;
    }

    try {
      if (!await store.isAvailable()) {
        _setUnavailable('Google Play billing is unavailable on this device.');
        return;
      }

      final response = await store.queryProductDetails(
        PurchaseCatalog.productIds,
      );
      if (response.error != null) {
        _setError(response.error!.message);
        return;
      }

      final matches = response.productDetails
          .where((candidate) => candidate.id == PurchaseCatalog.gold500Id)
          .toList(growable: false);
      if (matches.isEmpty) {
        _setUnavailable('500 Gold is not available in Google Play yet.');
        return;
      }

      product = matches.first;
      state = GoldPurchaseState.ready;
      message = null;
      notifyListeners();
    } catch (error) {
      _setError('Unable to load Google Play billing: $error');
    }
  }

  /// Starts the store checkout. Delivery is handled by [purchaseStream].
  Future<void> buyGold() async {
    if (!canBuy || product == null) return;

    state = GoldPurchaseState.purchasing;
    message = null;
    notifyListeners();

    try {
      final started = await store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product!),
      );
      if (!started) {
        _setError('Google Play could not start the purchase.');
      }
    } catch (error) {
      _setError('Unable to start the Gold purchase: $error');
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != PurchaseCatalog.gold500Id) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = GoldPurchaseState.pending;
          message = 'Payment is pending confirmation from Google Play.';
          notifyListeners();
        case PurchaseStatus.canceled:
          state = GoldPurchaseState.ready;
          message = 'Purchase canceled.';
          notifyListeners();
        case PurchaseStatus.error:
          state = GoldPurchaseState.error;
          message = purchase.error?.message ?? 'Google Play purchase failed.';
          notifyListeners();
        case PurchaseStatus.restored:
          // Gold is consumable. Restored purchases are not delivered again;
          // the local profile already records any purchase that was delivered.
          state = GoldPurchaseState.ready;
          message = null;
          notifyListeners();
        case PurchaseStatus.purchased:
          await _deliverPurchase(purchase);
      }
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final purchaseId = (purchase.purchaseID ?? '').trim().isNotEmpty
        ? purchase.purchaseID!.trim()
        : purchase.verificationData.serverVerificationData.trim();

    if (purchaseId.isEmpty) {
      _setError('Google Play returned a purchase without an ID.');
      return;
    }

    try {
      final granted = await save.grantPurchasedGold(
        productId: purchase.productID,
        purchaseId: purchaseId,
      );

      if (purchase.pendingCompletePurchase) {
        await store.completePurchase(purchase);
      }

      state = granted ? GoldPurchaseState.success : GoldPurchaseState.ready;
      message = granted ? '500 Gold added to your balance.' : null;
      notifyListeners();
    } catch (error) {
      _setError('Gold could not be added: $error');
    }
  }

  void _setUnavailable(String text) {
    state = GoldPurchaseState.unavailable;
    product = null;
    message = text;
    notifyListeners();
  }

  void _setError(String text) {
    state = GoldPurchaseState.error;
    message = text;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
