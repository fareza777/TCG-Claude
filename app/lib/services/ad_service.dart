import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'save_service.dart';

/// Pure placement policy so gameplay code can be tested without the SDK.
abstract final class AdPolicy {
  static bool canShowBanner({
    required bool removeAds,
    bool configured = true,
  }) => !removeAds && configured;

  static bool canShowInterstitial({
    required bool removeAds,
    required bool ready,
    required bool inCooldown,
    bool configured = true,
  }) => !removeAds && configured && ready && !inCooldown;
}

abstract interface class AdBannerHandle {
  int get width;

  int get height;

  Widget buildWidget();

  void dispose();
}

abstract interface class AdInterstitialHandle {
  Future<void> show();

  void dispose();
}

abstract interface class AdPlatform {
  Future<void> initialize();

  Future<AdBannerHandle?> loadBanner(String adUnitId);

  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId);
}

class _GoogleBannerHandle implements AdBannerHandle {
  _GoogleBannerHandle(this._ad);

  final BannerAd _ad;

  @override
  int get width => _ad.size.width;

  @override
  int get height => _ad.size.height;

  @override
  Widget buildWidget() => AdWidget(ad: _ad);

  @override
  void dispose() => _ad.dispose();
}

class _GoogleInterstitialHandle implements AdInterstitialHandle {
  _GoogleInterstitialHandle(this._ad);

  final InterstitialAd _ad;

  @override
  Future<void> show() => _ad.show();

  @override
  void dispose() => _ad.dispose();
}

/// Production adapter around the Google Mobile Ads SDK.
class GoogleAdPlatform implements AdPlatform {
  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async {
    final completer = Completer<AdBannerHandle?>();
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!completer.isCompleted) {
            completer.complete(_GoogleBannerHandle(loaded as BannerAd));
          }
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async {
    final completer = Completer<AdInterstitialHandle?>();
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(_GoogleInterstitialHandle(ad));
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    return completer.future;
  }
}

/// Owns the SDK lifecycle and ensures an ad can never interrupt gameplay.
class AdService extends ChangeNotifier {
  AdService({
    required this.save,
    AdPlatform? platform,
    this.cooldown = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : platform = platform ?? GoogleAdPlatform(),
       now = now ?? DateTime.now {
    save.addListener(_onSaveChanged);
  }

  final SaveService save;
  final AdPlatform platform;
  final Duration cooldown;
  final DateTime Function() now;

  AdBannerHandle? _banner;
  AdInterstitialHandle? _interstitial;
  Timer? _bannerRetryTimer;
  DateTime? _lastInterstitialAt;
  bool _initialized = false;
  bool _loadingBanner = false;
  bool _loadingInterstitial = false;
  int _bannerRetryCount = 0;

  bool get adsEnabled => AdPolicy.canShowBanner(
    removeAds: save.removeAds,
    configured: AdMobConfig.hasEffectiveUnits,
  );

  AdBannerHandle? get banner => _banner;

  bool get _inCooldown =>
      _lastInterstitialAt != null &&
      now().difference(_lastInterstitialAt!) < cooldown;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await platform.initialize();
    } catch (error) {
      debugPrint('AdMob initialization deferred: $error');
    }
    await loadBanner();
  }

  Future<void> loadBanner() async {
    if (!adsEnabled || _loadingBanner || _banner != null) return;
    _loadingBanner = true;
    try {
      final loaded = await platform.loadBanner(AdMobConfig.bannerUnitId);
      if (loaded == null) {
        _scheduleBannerRetry();
        return;
      }
      _banner?.dispose();
      _banner = loaded;
      _bannerRetryCount = 0;
      notifyListeners();
    } finally {
      _loadingBanner = false;
    }
  }

  Future<void> preloadInterstitial() async {
    if (!adsEnabled || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    try {
      _interstitial = await platform.loadInterstitial(
        AdMobConfig.interstitialUnitId,
      );
    } finally {
      _loadingInterstitial = false;
    }
  }

  Future<bool> showInterstitialIfEligible() async {
    final ad = _interstitial;
    final eligible = AdPolicy.canShowInterstitial(
      removeAds: save.removeAds,
      ready: ad != null,
      inCooldown: _inCooldown,
      configured: AdMobConfig.hasEffectiveUnits,
    );
    if (!eligible || ad == null) return false;

    _interstitial = null;
    try {
      await ad.show();
      _lastInterstitialAt = now();
      return true;
    } catch (error) {
      debugPrint('Interstitial display skipped: $error');
      return false;
    } finally {
      ad.dispose();
      unawaited(preloadInterstitial());
    }
  }

  void _onSaveChanged() {
    if (save.removeAds) {
      _banner?.dispose();
      _banner = null;
      _interstitial?.dispose();
      _interstitial = null;
      _bannerRetryTimer?.cancel();
      _bannerRetryTimer = null;
      notifyListeners();
    } else if (_initialized) {
      unawaited(loadBanner());
      unawaited(preloadInterstitial());
      notifyListeners();
    }
  }

  void _scheduleBannerRetry() {
    if (_bannerRetryTimer != null || _bannerRetryCount >= 3 || !adsEnabled) {
      return;
    }
    _bannerRetryCount++;
    _bannerRetryTimer = Timer(Duration(seconds: 5 * _bannerRetryCount), () {
      _bannerRetryTimer = null;
      unawaited(loadBanner());
    });
  }

  @override
  void dispose() {
    save.removeListener(_onSaveChanged);
    _bannerRetryTimer?.cancel();
    _banner?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}
