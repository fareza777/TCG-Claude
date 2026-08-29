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

  test('every mode that ends a battle goes through the seam', () {
    // The other half of the guarantee. The first test stops a screen showing
    // an ad the wrong way; this one stops a screen forgetting to show one at
    // all -- and, because the seam is also where a battle gets counted, a mode
    // that skips it would quietly hold the grace period open forever.
    const modes = {
      'story/chapter_player.dart': 'story battles',
      'arena/arena_screen.dart': 'arena runs',
      'gauntlet/gauntlet_screen.dart': 'the daily gauntlet',
      'main.dart': 'free duels',
    };

    final missing = <String>[];
    modes.forEach((path, what) {
      final source = File('lib/$path').readAsStringSync();
      if (!source.contains('showPostResultInterstitial')) {
        missing.add('$what ($path)');
      }
    });

    expect(missing, isEmpty,
        reason: 'these finish a battle without going through the seam, so '
            'they neither show an ad nor count the battle: '
            '${missing.join(", ")}');
  });
}
