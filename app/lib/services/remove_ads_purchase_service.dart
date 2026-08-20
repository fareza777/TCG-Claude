import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_catalog.dart';
import 'purchase_verifier.dart';
import 'save_service.dart';

/// UI-facing states for the permanent Remove Ads purchase.
enum RemoveAdsPurchaseState {
  loading,
  ready,
  unavailable,
  purchasing,
  pending,
  owned,
  error,
}

/// Small adapter around Google Play Billing for deterministic tests.
abstract interface class RemoveAdsStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> completePurchase(PurchaseDetails purchase);

  Future<void> restorePurchases();
}

/// Production adapter for the Flutter in-app purchase plugin.
class FlutterRemoveAdsStore implements RemoveAdsStore {
  FlutterRemoveAdsStore({InAppPurchase? instance})
    : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _instance.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _instance.completePurchase(purchase);
  }

  @override
  Future<void> restorePurchases() => _instance.restorePurchases();
}

/// Loads and delivers the permanent Remove Ads Play product.
class RemoveAdsPurchaseService extends ChangeNotifier {
  RemoveAdsPurchaseService({
    required this.save,
    RemoveAdsStore? store,
    this.verifier,
  }) : store = store ?? FlutterRemoveAdsStore() {
    save.addListener(_onSaveChanged);
  }

  final SaveService save;
  final RemoveAdsStore store;
  final PurchaseVerifier? verifier;

  RemoveAdsPurchaseState state = RemoveAdsPurchaseState.loading;
  ProductDetails? product;
  String? message;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _initialized = false;

  bool get canBuy =>
      !save.removeAds &&
      product != null &&
      (state == RemoveAdsPurchaseState.ready ||
          state == RemoveAdsPurchaseState.error);

  String get priceLabel => product?.price ?? 'US\$4.99';

  /// Subscribes before querying so a Play update cannot be missed.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _purchaseSubscription = store.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchases(purchases)),
      onError: (Object error, StackTrace stackTrace) {
        state = RemoveAdsPurchaseState.error;
        message = 'Google Play billing encountered an error.';
        notifyListeners();
      },
    );

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _setUnavailable('Remove Ads is available on Android only.');
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
          .where((candidate) => candidate.id == PurchaseCatalog.removeAdsId)
          .toList(growable: false);
      if (matches.isEmpty) {
        _setUnavailable('Remove Ads is not available in Google Play yet.');
        return;
      }

      product = matches.first;
      state = save.removeAds
          ? RemoveAdsPurchaseState.owned
          : RemoveAdsPurchaseState.ready;
      message = null;
      notifyListeners();

      await restorePurchases();
    } catch (_) {
      _setError('Unable to load Google Play billing.');
    }
  }

  /// Starts the non-consumable checkout. Delivery remains stream-driven.
  Future<void> buyRemoveAds() async {
    if (!canBuy || product == null) return;

    state = RemoveAdsPurchaseState.purchasing;
    message = null;
    notifyListeners();

    try {
      final started = await store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product!),
      );
      if (!started) {
        _setError('Google Play could not start the purchase.');
      }
    } catch (_) {
      _setError('Unable to start the Remove Ads purchase.');
    }
  }

  /// Explicit restore action from Settings.
  Future<void> restorePurchases() async {
    try {
      await store.restorePurchases();
    } catch (_) {
      // A restore outage must not clear local ownership or disable checkout.
      if (save.removeAds) {
        state = RemoveAdsPurchaseState.owned;
      } else if (product != null) {
        state = RemoveAdsPurchaseState.ready;
      }
      message = 'Restore is temporarily unavailable.';
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != PurchaseCatalog.removeAdsId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = RemoveAdsPurchaseState.pending;
          message = 'Payment is pending confirmation from Google Play.';
          notifyListeners();
        case PurchaseStatus.canceled:
          state = save.removeAds
              ? RemoveAdsPurchaseState.owned
              : RemoveAdsPurchaseState.ready;
          message = 'Purchase canceled.';
          notifyListeners();
        case PurchaseStatus.error:
          _setError(purchase.error?.message ?? 'Google Play purchase failed.');
        case PurchaseStatus.restored:
        case PurchaseStatus.purchased:
          await _deliverPurchase(purchase);
      }
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData.trim();
    final orderId = (purchase.purchaseID ?? '').trim();
    final purchaseId = token.isNotEmpty ? token : orderId;

    if (purchaseId.isEmpty) {
      _setError('Google Play returned a purchase without an ID.');
      return;
    }

    try {
      final granted = await save.grantRemoveAds(
        productId: purchase.productID,
        purchaseId: purchaseId,
        aliasIds: {if (orderId.isNotEmpty) orderId},
      );

      if (purchase.pendingCompletePurchase) {
        await store.completePurchase(purchase);
      }

      state = save.removeAds
          ? RemoveAdsPurchaseState.owned
          : RemoveAdsPurchaseState.ready;
      message = granted ? 'Ads removed from Shardfall.' : null;
      notifyListeners();

      if (granted && token.isNotEmpty) {
        await _recordWithBackend(purchase.productID, token);
      }
    } catch (_) {
      _setError('Remove Ads could not be applied.');
    }
  }

  Future<void> _recordWithBackend(String productId, String token) async {
    await save.markPurchaseUnverified(productId, token);

    final verify = verifier;
    if (verify == null) return;

    try {
      if (await verify(productId: productId, purchaseToken: token)) {
        await save.markPurchaseVerified(productId, token);
      }
    } catch (error) {
      debugPrint('Purchase verification deferred: $error');
    }
  }

  void _setUnavailable(String text) {
    state = RemoveAdsPurchaseState.unavailable;
    product = null;
    message = text;
    notifyListeners();
  }

  void _setError(String text) {
    state = RemoveAdsPurchaseState.error;
    message = text;
    notifyListeners();
  }

  void _onSaveChanged() {
    final next = save.removeAds
        ? RemoveAdsPurchaseState.owned
        : state == RemoveAdsPurchaseState.owned
        ? RemoveAdsPurchaseState.ready
        : state;
    if (next == state) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    save.removeListener(_onSaveChanged);
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
