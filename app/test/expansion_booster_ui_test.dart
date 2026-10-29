import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/data/card_catalog.dart';
import 'package:shardfall/packs/booster_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/auth_service.dart';
import 'package:shardfall/services/gold_purchase_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'expansion_packs_test.dart' show packLibrary;

class _GuestAuth extends AuthService {
  @override
  bool get isSignedIn => false;
}

class _NoAds implements AdPlatform {
  @override
  Future<void> initialize() async {}
  @override
  Future<AdBannerHandle?> loadBanner(String id) async => null;
  @override
  Future<AdInterstitialHandle?> loadInterstitial(String id) async => null;
  @override
  Future<AdRewardedHandle?> loadRewarded(String id) async => null;
}

void main() {
  testWidgets(
    'selected pack labels, odds, double tap and pulls agree on narrow phone',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'gold': 500,
        'lastLoginDate': '2026-10-28',
      });
      final library = packLibrary();
      final save = await SaveService.load(library);
      final ads = AdService(save: save, platform: _NoAds());
      final auth = _GuestAuth();
      final purchases = GoldPurchaseService(save: save);
      addTearDown(ads.dispose);
      addTearDown(auth.dispose);
      addTearDown(purchases.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(
        MaterialApp(
          home: BoosterScreen(
            library: library,
            save: save,
            purchaseService: purchases,
            auth: auth,
            adService: ads,
            initialSet: CardSet.fiveVows,
          ),
        ),
      );
      expect(find.text('THE FIVE VOWS'), findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('THE FIVE VOWS'))
            .didExceedMaxLines,
        isFalse,
      );

      await tester.tap(find.text('View pack odds'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('The Five Vows · pack odds'), findsOneWidget);
      expect(find.textContaining('selected set'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('The Five Vows · pack odds')),
      ).pop();
      await tester.pump(const Duration(milliseconds: 400));
      final goldBefore = save.gold;
      await tester.tap(find.byKey(const ValueKey('open-pack')));
      await tester.tap(find.byKey(const ValueKey('open-pack')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(save.totalPacks, 1);
      expect(save.gold, goldBefore - SaveService.packCost);
      expect(save.owned.keys.every(CardSet.fiveVows.contains), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
