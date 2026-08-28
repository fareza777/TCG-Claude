import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/season/season.dart';

/// A progression track is a promise about numbers. If the arithmetic is wrong
/// the player is either cheated or handed infinite Gold, and both are found by
/// players long before they are found by reading the code.
void main() {
  test('the track is monotonic and reaches its end', () {
    final tiers = Season.tiers;

    expect(tiers, hasLength(Season.tierCount));
    for (var i = 1; i < tiers.length; i++) {
      expect(tiers[i].xpRequired, greaterThan(tiers[i - 1].xpRequired),
          reason: 'tier ${tiers[i].tier} is not further along than the one '
              'before it');
    }
    expect(tiers.last.xpRequired, Season.tierCount * Season.xpPerTier);
  });

  test('every tier pays something', () {
    for (final tier in Season.tiers) {
      expect(tier.gold + tier.shards, greaterThan(0),
          reason: 'tier ${tier.tier} is a rung with nothing on it');
      expect(tier.rewardLabel, isNotEmpty);
    }
  });

  test('milestones land every fifth rung and pay a pack', () {
    final milestones = Season.tiers.where((t) => t.milestone).toList();

    expect(milestones, hasLength(Season.tierCount ~/ 5));
    for (final tier in milestones) {
      expect(tier.tier % 5, 0);
      expect(tier.gold, greaterThanOrEqualTo(100),
          reason: 'a milestone should buy a booster outright');
    }
  });

  test('tier is earned, never overshot', () {
    expect(Season.tierFor(0), 0);
    expect(Season.tierFor(Season.xpPerTier - 1), 0,
        reason: 'one XP short is not a tier');
    expect(Season.tierFor(Season.xpPerTier), 1);
    expect(Season.tierFor(Season.xpPerTier * 3 + 40), 3);
  });

  test('the bar cannot run past the end of the track', () {
    final beyond = Season.xpPerTier * (Season.tierCount + 20);

    expect(Season.tierFor(beyond), Season.tierCount);
    expect(Season.progressInTier(beyond), 1.0);
  });

  test('progress within a tier is a real fraction', () {
    expect(Season.progressInTier(0), 0.0);
    expect(Season.progressInTier(Season.xpPerTier ~/ 2), closeTo(0.5, 0.001));
    for (final xp in [0, 1, 99, 100, 355, 2999]) {
      final p = Season.progressInTier(xp);
      expect(p, inInclusiveRange(0.0, 1.0), reason: 'at $xp XP');
    }
  });

  test('a season is the calendar month it falls in', () {
    expect(Season.idFor(DateTime(2026, 8, 27)), '2026-08');
    expect(Season.idFor(DateTime(2026, 12, 31)), '2026-12');
    expect(Season.idFor(DateTime(2026, 1, 1)), '2026-01',
        reason: 'single-digit months must pad or sort order breaks');
  });

  test('a season ends when the next one starts', () {
    expect(Season.endOf('2026-08'), DateTime(2026, 9, 1));
    expect(Season.endOf('2026-12'), DateTime(2027, 1, 1),
        reason: 'December must roll the year, not produce month 13');
  });

  test('every XP event is actually emitted by the app', () {
    // A reward keyed to an event nothing sends is a reward nobody can earn.
    // This reads the source rather than trusting the comment above the map,
    // because that comment was wrong once already.
    final sources = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        sources.add(entity.readAsStringSync());
      }
    }
    final all = sources.join('\n');

    for (final event in Season.xpFor.keys) {
      expect(all, contains("trackQuest('$event')"),
          reason: '$event pays XP but no screen ever sends it');
    }
  });

  test('a loss pays, and pays less than a win', () {
    final loss = Season.xpFor['battle_loss'];

    expect(loss, isNotNull, reason: 'three losses end an Arena run; paying '
        'nothing for them makes the run feel wasted');
    expect(loss, greaterThan(0));
    for (final win in ['duel_win', 'story_win', 'pvp_win']) {
      expect(loss, lessThan(Season.xpFor[win]!),
          reason: 'losing must never be worth as much as $win');
    }
  });

  test('the whole track is reachable by an ordinary player', () {
    // Thirty tiers at 50 XP is 1500. The first draft used 100 per tier, which
    // needed 3000 and made the track quietly uncompletable -- this test is
    // what caught it. It stays so that any future tuning has to re-earn the
    // claim rather than silently breaking it.
    final perDay = Season.xpFor['duel_win']! * 3 +
        Season.xpFor['story_win']! * 2 +
        Season.xpPerPack;
    final month = perDay * 30;

    expect(month, greaterThanOrEqualTo(Season.tierCount * Season.xpPerTier),
        reason: 'three duels, two story battles and a pack a day should '
            'finish the track; at $perDay XP a day it reaches $month of '
            '${Season.tierCount * Season.xpPerTier}');
  });
}
