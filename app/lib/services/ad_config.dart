import 'package:flutter/foundation.dart';

/// Public AdMob identifiers. Production values are supplied from the AdMob
/// account; they are not secrets. Debug builds use Google's test units so a
/// developer never accidentally clicks a live ad.
abstract final class AdMobConfig {
  static const productionAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: '',
  );
  static const productionBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: '',
  );
  static const productionInterstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID',
    defaultValue: '',
  );

  static const testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const useTestAds = bool.fromEnvironment(
    'ADMOB_USE_TEST_ADS',
    defaultValue: false,
  );

  static bool get useTestUnits => kDebugMode || useTestAds;

  static String get bannerUnitId =>
      useTestUnits ? testBannerUnitId : productionBannerUnitId;

  static String get interstitialUnitId =>
      useTestUnits ? testInterstitialUnitId : productionInterstitialUnitId;

  static bool get hasEffectiveUnits =>
      bannerUnitId.isNotEmpty && interstitialUnitId.isNotEmpty;
}
