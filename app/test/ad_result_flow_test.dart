import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/ad_result_flow.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';

class _FakeInterstitial implements AdInterstitialHandle {
  int showCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> show() async => showCalls++;

  @override
  void dispose() => disposeCalls++;
}

class _FakePlatform implements AdPlatform {
  final _FakeInterstitial interstitial;

  _FakePlatform(this.interstitial);

  @override
  Future<void> initialize() async {}

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async => null;

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async =>
      interstitial;

  @override
  Future<AdRewardedHandle?> loadRewarded(String adUnitId) async => rewarded;

  /// Set by tests that exercise the rewarded path; null means "none loaded".
  AdRewardedHandle? rewarded;
}

class _GrantedConsentPlatform implements AdConsentPlatform {
  @override
  Future<bool> gatherConsent() async => true;

  @override
  Future<bool> get isPrivacyOptionsRequired async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
      // Past the new-player grace period; these cases are about the hook.
      'battlesPlayed': 99,
    });
  });

  test('post-result hook is a no-op when ads are unavailable', () async {
    expect(await showPostResultInterstitial(null), isFalse);
  });

  test('post-result hook delegates to a ready interstitial once', () async {
    final save = await SaveService.load(emptyLibrary);
    final interstitial = _FakeInterstitial();
    final service = AdService(
      save: save,
      platform: _FakePlatform(interstitial),
      consentPlatform: _GrantedConsentPlatform(),
      cooldown: Duration.zero,
    );

    await service.initialize();
    await service.preloadInterstitial();

    expect(await showPostResultInterstitial(service), isTrue);
    expect(interstitial.showCalls, 1);
    expect(interstitial.disposeCalls, 1);
  });
}
