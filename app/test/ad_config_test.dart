import 'package:flutter_test/flutter_test.dart';

import 'package:shardfall/services/ad_config.dart';

void main() {
  test('production AdMob identifiers are configured', () {
    expect(AdMobConfig.productionAppId,
        matches(RegExp(r'^ca-app-pub-\d+~\d+$')));
    expect(AdMobConfig.productionBannerUnitId,
        matches(RegExp(r'^ca-app-pub-\d+/\d+$')));
    expect(AdMobConfig.productionInterstitialUnitId,
        matches(RegExp(r'^ca-app-pub-\d+/\d+$')));
    expect(AdMobConfig.productionBannerUnitId,
        isNot(AdMobConfig.testBannerUnitId));
    expect(AdMobConfig.productionInterstitialUnitId,
        isNot(AdMobConfig.testInterstitialUnitId));
  });
}
