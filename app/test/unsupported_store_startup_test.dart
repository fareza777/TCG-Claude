import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/services/gold_purchase_service.dart';
import 'package:shardfall/services/remove_ads_purchase_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unsupported store plugins can throw even when their stream is accessed.
class _UnsupportedGoldStore implements GoldStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No billing plugin on this platform.');
}

class _UnsupportedRemoveAdsStore implements RemoveAdsStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No billing plugin on this platform.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({'gold': 120});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Gold initialization skips the plugin on unsupported platforms',
    () async {
      final save = await SaveService.load(
        const CardLibrary(byId: {}, starterDecks: {}),
      );
      final service = GoldPurchaseService(
        save: save,
        store: _UnsupportedGoldStore(),
      );
      final goldBefore = save.gold;
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.state, GoldPurchaseState.unavailable);
      expect(service.canBuy, isFalse);
      expect(save.gold, goldBefore);
    },
  );

  test(
    'Remove Ads initialization skips the plugin on unsupported platforms',
    () async {
      final save = await SaveService.load(
        const CardLibrary(byId: {}, starterDecks: {}),
      );
      final service = RemoveAdsPurchaseService(
        save: save,
        store: _UnsupportedRemoveAdsStore(),
      );
      final goldBefore = save.gold;
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.state, RemoveAdsPurchaseState.unavailable);
      expect(service.canBuy, isFalse);
      expect(save.gold, goldBefore);
    },
  );
}
