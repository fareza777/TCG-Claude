import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';

class _FakeBannerHandle implements AdBannerHandle {
  @override
  final int width = 320;

  @override
  final int height = 50;

  int disposeCalls = 0;

  @override
  Widget buildWidget() => const ColoredBox(color: Colors.red);

  @override
  void dispose() => disposeCalls++;
}

class _FakeInterstitialHandle implements AdInterstitialHandle {
  int showCalls = 0;
  int disposeCalls = 0;
  bool shouldThrow = false;

  @override
  Future<void> show() async {
    if (shouldThrow) throw StateError('ad failed');
    showCalls++;
  }

  @override
  void dispose() => disposeCalls++;
}

class _FakeAdPlatform implements AdPlatform {
  int initializeCalls = 0;
  int bannerLoads = 0;
  int interstitialLoads = 0;
  _FakeBannerHandle? banner;
  _FakeInterstitialHandle? interstitial;
  final interstitialQueue = <_FakeInterstitialHandle>[];
  bool failBanner = false;
  bool failInterstitial = false;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async {
    bannerLoads++;
    if (failBanner) return null;
    return banner ??= _FakeBannerHandle();
  }

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async {
    interstitialLoads++;
    if (failInterstitial) return null;
    if (interstitialQueue.isNotEmpty) return interstitialQueue.removeAt(0);
    return interstitial ??= _FakeInterstitialHandle();
  }

  @override
  Future<AdRewardedHandle?> loadRewarded(String adUnitId) async => rewarded;

  /// Set by tests that exercise the rewarded path; null means "none loaded".
  AdRewardedHandle? rewarded;
}

class _HangingConsentPlatform implements AdConsentPlatform {
  @override
  Future<bool> gatherConsent() => Completer<bool>().future;

  @override
  Future<bool> get isPrivacyOptionsRequired async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class _FakeConsentPlatform implements AdConsentPlatform {
  _FakeConsentPlatform({
    this.canRequestAds = true,
    this.privacyOptionsRequired = false,
  });

  bool canRequestAds;
  bool privacyOptionsRequired;
  int gatherCalls = 0;
  int privacyOptionsCalls = 0;

  @override
  Future<bool> gatherConsent() async {
    gatherCalls++;
    return canRequestAds;
  }

  @override
  Future<bool> get isPrivacyOptionsRequired async => privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptions() async => privacyOptionsCalls++;
}

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
      // Most cases here are about a settled player, so they start past the
      // new-player grace period. The grace itself has its own test below.
      'battlesPlayed': 99,
    });
  });

  test('a new player finishes their first fights without an interstitial', () {
    // Interrupting someone in their first session is the cheapest way to lose
    // them, and a player lost on day one never sees a second impression.
    for (var played = 0; played < AdPolicy.graceBattles; played++) {
      expect(
        AdPolicy.canShowInterstitial(
          removeAds: false,
          ready: true,
          inCooldown: false,
          battlesPlayed: played,
        ),
        isFalse,
        reason: 'battle ${played + 1} should not carry an ad',
      );
    }
    expect(
      AdPolicy.canShowInterstitial(
        removeAds: false,
        ready: true,
        inCooldown: false,
        battlesPlayed: AdPolicy.graceBattles,
      ),
      isTrue,
      reason: 'the fight after the grace period is the first with an ad',
    );
  });

  test('rewarded offers survive Remove Ads', () {
    // Remove Ads buys freedom from interruptions, not from choosing to earn.
    expect(AdPolicy.canOfferRewarded(ready: true), isTrue);
    expect(AdPolicy.canOfferRewarded(ready: false), isFalse);
    expect(AdPolicy.canOfferRewarded(ready: true, configured: false), isFalse);
  });

  test('policy skips banners and interstitials when Remove Ads is owned', () {
    expect(AdPolicy.canShowBanner(removeAds: false), isTrue);
    expect(AdPolicy.canShowBanner(removeAds: true), isFalse);
    expect(
      AdPolicy.canShowInterstitial(
        removeAds: false,
        ready: false,
        inCooldown: false,
        battlesPlayed: 99,
      ),
      isFalse,
    );
    expect(
      AdPolicy.canShowInterstitial(
        removeAds: false,
        ready: true,
        inCooldown: false,
        battlesPlayed: 99,
      ),
      isTrue,
    );
    expect(
      AdPolicy.canShowInterstitial(
        removeAds: true,
        ready: true,
        inCooldown: false,
        battlesPlayed: 99,
      ),
      isFalse,
    );
  });

  test('initializes, loads a banner, and shows a ready interstitial', () async {
    final save = await SaveService.load(emptyLibrary);
    final platform = _FakeAdPlatform();
    final service = AdService(
      save: save,
      platform: platform,
      consentPlatform: _FakeConsentPlatform(),
      cooldown: Duration.zero,
    );

    await service.initialize();
    expect(platform.initializeCalls, 1);
    final banner = await service.loadBanner();
    expect(platform.bannerLoads, 1);
    expect(banner, isNotNull);

    await service.preloadInterstitial();
    expect(platform.interstitialLoads, 1);
    expect(await service.showInterstitialIfEligible(), isTrue);
    expect(platform.interstitial?.showCalls, 1);
    expect(platform.interstitial?.disposeCalls, 1);
    expect(banner, isNotNull);
  });

  test('does not load or show ads after Remove Ads is granted', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantRemoveAds(
      productId: 'remove_ads',
      purchaseId: 'remove-token',
    );
    final platform = _FakeAdPlatform();
    final service = AdService(
      save: save,
      platform: platform,
      consentPlatform: _FakeConsentPlatform(),
    );

    await service.initialize();
    await service.preloadInterstitial();

    expect(service.adsEnabled, isFalse);
    expect(await service.loadBanner(), isNull);
    expect(platform.bannerLoads, 0);
    expect(await service.showInterstitialIfEligible(), isFalse);
    expect(platform.interstitialLoads, 0);
  });

  test('load failures are soft and cooldown prevents repeated shows', () async {
    final save = await SaveService.load(emptyLibrary);
    var now = DateTime(2026, 8, 20, 10);
    final platform = _FakeAdPlatform()..failBanner = true;
    final service = AdService(
      save: save,
      platform: platform,
      consentPlatform: _FakeConsentPlatform(),
      cooldown: const Duration(minutes: 5),
      now: () => now,
    );

    await service.initialize();
    expect(await service.loadBanner(), isNull);

    final first = _FakeInterstitialHandle();
    final second = _FakeInterstitialHandle();
    platform.interstitialQueue.addAll([first, second]);
    platform.interstitial = first;
    await service.preloadInterstitial();
    expect(await service.showInterstitialIfEligible(), isTrue);

    await service.preloadInterstitial();
    expect(await service.showInterstitialIfEligible(), isFalse);
    expect(second.showCalls, 0);

    now = now.add(const Duration(minutes: 5));
    expect(await service.showInterstitialIfEligible(), isTrue);
    expect(second.showCalls, 1);
  });

  test(
    'an interstitial show error is disposed and never blocks the caller',
    () async {
      final save = await SaveService.load(emptyLibrary);
      final platform = _FakeAdPlatform();
      final failing = _FakeInterstitialHandle()..shouldThrow = true;
      platform.interstitial = failing;
      final service = AdService(
        save: save,
        platform: platform,
        consentPlatform: _FakeConsentPlatform(),
        cooldown: Duration.zero,
      );

      await service.initialize();
      await service.preloadInterstitial();

      expect(await service.showInterstitialIfEligible(), isFalse);
      expect(failing.disposeCalls, 1);
    },
  );

  test('does not initialize or request ads before consent allows it', () async {
    final save = await SaveService.load(emptyLibrary);
    final platform = _FakeAdPlatform();
    final consent = _FakeConsentPlatform(canRequestAds: false);
    final service = AdService(
      save: save,
      platform: platform,
      consentPlatform: consent,
    );

    await service.initialize();
    await service.preloadInterstitial();

    expect(consent.gatherCalls, 1);
    expect(platform.initializeCalls, 0);
    expect(platform.interstitialLoads, 0);
    expect(await service.loadBanner(), isNull);
  });

  test('a hung consent prompt fails soft instead of blocking the game', () async {
    final save = await SaveService.load(emptyLibrary);
    final platform = _FakeAdPlatform();
    final service = AdService(
      save: save,
      platform: platform,
      consentPlatform: _HangingConsentPlatform(),
      consentTimeout: const Duration(milliseconds: 30),
    );

    await service.initialize();
    expect(platform.initializeCalls, 0);
    expect(service.adsEnabled, isFalse);
  });

  test(
    'exposes required privacy options and presents them on request',
    () async {
      final save = await SaveService.load(emptyLibrary);
      final consent = _FakeConsentPlatform(privacyOptionsRequired: true);
      final service = AdService(
        save: save,
        platform: _FakeAdPlatform(),
        consentPlatform: consent,
      );

      await service.initialize();
      expect(service.privacyOptionsRequired, isTrue);

      await service.showPrivacyOptions();
      expect(consent.privacyOptionsCalls, 1);
    },
  );
}
