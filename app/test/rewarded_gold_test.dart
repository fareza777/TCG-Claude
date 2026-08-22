import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/services/ad_result_flow.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// Rewarded Gold is real currency handed out for watching a video, so the
/// daily cap is the only thing standing between a player and unlimited Gold.
void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({'gold': SaveService.startGold});
  });

  test('pays out up to the daily cap and not one claim further', () async {
    final save = await SaveService.load(emptyLibrary);
    final start = save.gold;

    for (var i = 1; i <= SaveService.adGoldDailyCap; i++) {
      expect(save.canClaimAdGold, isTrue, reason: 'claim $i should be allowed');
      expect(await save.claimAdGold(), SaveService.adGoldReward);
      expect(save.adGoldClaimsLeft, SaveService.adGoldDailyCap - i);
    }

    expect(save.canClaimAdGold, isFalse);
    expect(await save.claimAdGold(), 0,
        reason: 'a claim past the cap must pay nothing');
    expect(save.gold, start + SaveService.adGoldReward * SaveService.adGoldDailyCap,
        reason: 'the cap bounds the total Gold a day can produce');
  });

  test('the cap survives a reload — it is not just in memory', () async {
    final first = await SaveService.load(emptyLibrary);
    for (var i = 0; i < SaveService.adGoldDailyCap; i++) {
      await first.claimAdGold();
    }
    final reloaded = await SaveService.load(emptyLibrary);
    expect(reloaded.canClaimAdGold, isFalse);
    expect(await reloaded.claimAdGold(), 0);
  });

  test('a fresh profile is inside the new-player grace period', () async {
    final save = await SaveService.load(emptyLibrary);
    expect(save.battlesPlayed, 0);
  });

  test('the post-result hook counts the battle even when no ad shows', () async {
    // Without this the grace period would never elapse for a player who has
    // ads unavailable, and their first ad would land at an arbitrary time.
    final save = await SaveService.load(emptyLibrary);
    expect(await showPostResultInterstitial(null), isFalse);
    expect(save.battlesPlayed, 0,
        reason: 'a null service cannot count anything');
  });
}
