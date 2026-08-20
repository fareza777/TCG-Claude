import 'dart:async';

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

/// Privacy boundary kept separate from ad loading so no ad request can be
/// created until Google's latest consent state explicitly permits it.
abstract interface class AdConsentPlatform {
  Future<bool> gatherConsent();

  Future<bool> get isPrivacyOptionsRequired;

  Future<void> showPrivacyOptions();
}

class GoogleAdConsentPlatform implements AdConsentPlatform {
  @override
  Future<bool> gatherConsent() async {
    final completer = Completer<bool>();

    Future<void> finish() async {
      try {
        final allowed = await ConsentInformation.instance.canRequestAds();
        if (!completer.isCompleted) completer.complete(allowed);
      } catch (error) {
        if (!completer.isCompleted) completer.complete(false);
        debugPrint('Ad consent status unavailable: $error');
      }
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint(
                'Ad consent form unavailable: ${formError.errorCode} '
                '${formError.message}',
              );
            }
            unawaited(finish());
          });
        },
        (error) {
          debugPrint(
            'Ad consent refresh failed: ${error.errorCode} ${error.message}',
          );
          // Google's cached state can still be valid after a refresh error.
          unawaited(finish());
        },
      );
    } catch (error) {
      debugPrint('Ad consent collection failed: $error');
      await finish();
    }

    return completer.future;
  }

  @override
  Future<bool> get isPrivacyOptionsRequired async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    FormError? failure;
    await ConsentForm.showPrivacyOptionsForm((formError) {
      failure = formError;
    });
    if (failure != null) {
      throw StateError(
        'Privacy options unavailable: ${failure!.errorCode} '
        '${failure!.message}',
      );
    }
  }
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
    AdConsentPlatform? consentPlatform,
    this.cooldown = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : platform = platform ?? GoogleAdPlatform(),
       consentPlatform = consentPlatform ?? GoogleAdConsentPlatform(),
       now = now ?? DateTime.now {
    save.addListener(_onSaveChanged);
  }

  final SaveService save;
  final AdPlatform platform;
  final AdConsentPlatform consentPlatform;
  final Duration cooldown;
  final DateTime Function() now;

  AdInterstitialHandle? _interstitial;
  DateTime? _lastInterstitialAt;
  bool _initializationStarted = false;
  bool _sdkInitialized = false;
  bool _consentAllowsAds = false;
  bool _privacyOptionsRequired = false;
  bool _loadingInterstitial = false;

  bool get adsEnabled => AdPolicy.canShowBanner(
    removeAds: save.removeAds,
    configured:
        AdMobConfig.hasEffectiveUnits && _consentAllowsAds && _sdkInitialized,
  );

  bool get privacyOptionsRequired => _privacyOptionsRequired;

  bool get _inCooldown =>
      _lastInterstitialAt != null &&
      now().difference(_lastInterstitialAt!) < cooldown;

  Future<void> initialize() async {
    if (_initializationStarted) return;
    _initializationStarted = true;
    try {
      _consentAllowsAds = await consentPlatform.gatherConsent();
      _privacyOptionsRequired = await consentPlatform.isPrivacyOptionsRequired;
      if (!_consentAllowsAds) {
        notifyListeners();
        return;
      }
      await platform.initialize();
      _sdkInitialized = true;
      notifyListeners();
    } catch (error) {
      debugPrint('AdMob initialization deferred: $error');
    }
  }

  Future<void> showPrivacyOptions() async {
    if (!_privacyOptionsRequired) return;
    try {
      await consentPlatform.showPrivacyOptions();
      _consentAllowsAds = await consentPlatform.gatherConsent();
      _privacyOptionsRequired = await consentPlatform.isPrivacyOptionsRequired;
      notifyListeners();
    } catch (error) {
      debugPrint('Privacy options display skipped: $error');
    }
  }

  /// Creates an independent banner for one mounted screen. A route beneath
  /// the current route can remain mounted, so sharing one [BannerAd] between
  /// screens would violate AdWidget's single-mount contract.
  Future<AdBannerHandle?> loadBanner() async {
    if (!adsEnabled) return null;
    try {
      return await platform.loadBanner(AdMobConfig.bannerUnitId);
    } catch (error) {
      debugPrint('Banner load skipped: $error');
      return null;
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
      _interstitial?.dispose();
      _interstitial = null;
      notifyListeners();
    } else if (_sdkInitialized) {
      unawaited(preloadInterstitial());
      notifyListeners();
    }
  }

  @override
  void dispose() {
    save.removeListener(_onSaveChanged);
    _interstitial?.dispose();
    super.dispose();
  }
}
