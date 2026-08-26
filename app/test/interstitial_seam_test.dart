import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Interstitials must only ever fire through one seam.
///
/// `showPostResultInterstitial` is also where a finished battle gets counted,
/// and that count is what holds ads off a new player's first three fights.
/// A screen that calls the ad service directly would skip the grace period
/// without anything failing — the player would just get an ad they should not
/// have seen, and nobody would know.
void main() {
  test('nothing shows an interstitial except the post-result seam', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('services/ad_service.dart')) continue;
      if (path.endsWith('services/ad_result_flow.dart')) continue;
      if (entity.readAsStringSync().contains('showInterstitialIfEligible')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'call showPostResultInterstitial instead, so the new-player '
            'grace period cannot be skipped: ${offenders.join(", ")}');
  });
}
