import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/remove_ads_purchase_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/widgets/ad_banner.dart';
import 'package:shardfall/widgets/remove_ads_offer.dart';

class _BannerHandle implements AdBannerHandle {
  @override
  int get width => 320;

  @override
  int get height => 50;

  @override
  Widget buildWidget() => const ColoredBox(color: Colors.red);

  @override
  void dispose() {}
}

class _InterstitialHandle implements AdInterstitialHandle {
  @override
  Future<void> show() async {}

  @override
  void dispose() {}
}

class _AdPlatform implements AdPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async => _BannerHandle();

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async =>
      _InterstitialHandle();
}

class _GrantedConsentPlatform implements AdConsentPlatform {
  @override
  Future<bool> gatherConsent() async => true;

  @override
  Future<bool> get isPrivacyOptionsRequired async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class _Store implements RemoveAdsStore {
  _Store()
    : product = ProductDetails(
        id: 'remove_ads',
        title: 'Remove Ads',
        description: 'Remove all in-game advertisements.',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      );

  final ProductDetails product;
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: [product], notFoundIDs: const []);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}

  Future<void> close() => _stream.close();
}

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
    });
  });

  testWidgets('banner disappears immediately after Remove Ads is granted', (
    tester,
  ) async {
    final save = await SaveService.load(emptyLibrary);
    final ads = AdService(
      save: save,
      platform: _AdPlatform(),
      consentPlatform: _GrantedConsentPlatform(),
    );
    await ads.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdBanner(adService: ads)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('ad-banner')), findsOneWidget);

    await save.grantRemoveAds(productId: 'remove_ads', purchaseId: 'token-1');
    await tester.pump();
    expect(find.byKey(const ValueKey('ad-banner')), findsNothing);
    ads.dispose();
  });

  testWidgets('Remove Ads offer shows price, progress, and Restore states', (
    tester,
  ) async {
    final save = await SaveService.load(emptyLibrary);
    final store = _Store();
    final purchases = RemoveAdsPurchaseService(save: save, store: store);
    await purchases.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoveAdsOffer(purchaseService: purchases, save: save),
        ),
      ),
    );
    expect(find.textContaining('\$4.99'), findsOneWidget);
    expect(find.text('Remove Ads'), findsOneWidget);
    expect(find.byKey(const ValueKey('remove-ads-restore')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-ads-buy')));
    await tester.pump();
    expect(find.text('Processing…'), findsOneWidget);

    await save.grantRemoveAds(productId: 'remove_ads', purchaseId: 'token-2');
    await tester.pump();
    expect(find.text('Ads removed'), findsOneWidget);
    expect(find.byKey(const ValueKey('remove-ads-restore')), findsOneWidget);

    purchases.dispose();
    await store.close();
  });
}
