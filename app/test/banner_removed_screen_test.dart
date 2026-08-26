import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/arena/arena_screen.dart';
import 'package:shardfall/collection/collection_screen.dart';
import 'package:shardfall/deckbuilder/deck_builder_screen.dart';
import 'package:shardfall/forge/forge_screen.dart';
import 'package:shardfall/progress/achievements_screen.dart';
import 'package:shardfall/quests/quests_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/story/story_screen.dart';
import 'package:shardfall/widgets/ad_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopAdPlatform implements AdPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async => null;

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async => null;

  @override
  Future<AdRewardedHandle?> loadRewarded(String adUnitId) async => null;
}

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '2026-08-25',
    });
  });

  testWidgets('non-gameplay screens render without a banner or banner slot', (
    tester,
  ) async {
    final save = await SaveService.load(emptyLibrary);
    final ads = AdService(save: save, platform: _NoopAdPlatform());
    final screens = <Widget>[
      QuestsScreen(save: save),
      AchievementsScreen(save: save),
      CollectionScreen(library: emptyLibrary, save: save),
      ForgeScreen(library: emptyLibrary, save: save),
      DeckBuilderScreen(library: emptyLibrary, save: save),
      StoryScreen(library: emptyLibrary, save: save, adService: ads),
      ArenaScreen(library: emptyLibrary, save: save, adService: ads),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();

      expect(
        find.byType(AdBanner),
        findsNothing,
        reason: '${screen.runtimeType} must not render an ad banner',
      );
      expect(
        find.byKey(const ValueKey('ad-banner')),
        findsNothing,
        reason: '${screen.runtimeType} must not reserve a banner slot',
      );
    }

    ads.dispose();
  });
}
