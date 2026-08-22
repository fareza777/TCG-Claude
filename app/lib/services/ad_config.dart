import 'package:flutter/foundation.dart';

/// Public AdMob identifiers. Production values are supplied from the AdMob
/// account; they are not secrets. Debug builds use Google's test units so a
/// developer never accidentally clicks a live ad.
abstract final class AdMobConfig {
  static const productionAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-6279186647593327~2315466241',
  );
  static const productionBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: 'ca-app-pub-6279186647593327/6469549858',
  );
  static const productionInterstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID',
    defaultValue: 'ca-app-pub-6279186647593327/9807672400',
  );

  /// Rewarded video used for the optional Gold reward and Arena revive.
  static const productionRewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
    defaultValue: 'ca-app-pub-6279186647593327/4838943412',
  );

  static const testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const testRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static const useTestAds = bool.fromEnvironment(
    'ADMOB_USE_TEST_ADS',
    defaultValue: false,
  );

  static bool get useTestUnits => kDebugMode || useTestAds;

  static String get bannerUnitId =>
      useTestUnits ? testBannerUnitId : productionBannerUnitId;

  static String get interstitialUnitId =>
      useTestUnits ? testInterstitialUnitId : productionInterstitialUnitId;

  static String get rewardedUnitId =>
      useTestUnits ? testRewardedUnitId : productionRewardedUnitId;

  static bool get hasEffectiveUnits =>
      bannerUnitId.isNotEmpty && interstitialUnitId.isNotEmpty;

  static bool get hasRewardedUnit => rewardedUnitId.isNotEmpty;
}
