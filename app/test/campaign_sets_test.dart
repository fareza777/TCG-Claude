import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/data/playable_decks.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/audio_manager.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/story/campaign_progress.dart';
import 'package:shardfall/story/chapter_player.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/story_screen.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

class _NoAds implements AdPlatform {
  @override
  Future<void> initialize() async {}
  @override
  Future<AdBannerHandle?> loadBanner(String id) async => null;
  @override
  Future<AdInterstitialHandle?> loadInterstitial(String id) async => null;
  @override
  Future<AdRewardedHandle?> loadRewarded(String id) async => null;
}

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  Future<SaveService> profile() async {
    SharedPreferences.setMockInitialValues({});
    return SaveService.load(library);
  }

  test('set partitions retain the global unlock boundary', () async {
    final save = await profile();
    expect(StoryCampaign.sundering.chapterIndices, [0, 1, 2, 3, 4]);
    expect(
      StoryCampaign.fiveVows.chapterIndices,
      List.generate(20, (i) => i + 5),
    );
    expect(storyChapterUnlocked(5, save), isFalse);
    save.chaptersDone.addAll(['ch1', 'ch2', 'ch3', 'ch4', 'ch5']);
    expect(storyChapterUnlocked(5, save), isTrue);
    expect(storyChapterUnlocked(6, save), isFalse);
  });
  test(
    'collection decks from both sets are legal; bad or unowned decks are excluded',
    () async {
      final save = await profile();
      final deck = BattleDecks.build(library, 'VERDANCE', seed: 19);
      save.owned.addAll({for (final c in library.byId.values) c.id: 3});
      save.decks['Mixed'] = deck.map((c) => c.id).toList();
      save.decks['Unknown'] = [...save.decks['Mixed']!.take(39), 'MISSING'];
      save.decks['Too short'] = save.decks['Mixed']!.take(39).toList();
      save.decks['Too long'] = [
        ...save.decks['Mixed']!,
        ...save.decks['Mixed']!,
      ];
      save.decks['Only resources'] = List.filled(40, 'SF002-001');
      save.decks['Four copies'] = [
        ...List.filled(4, 'SF002-002'),
        ...save.decks['Mixed']!.skip(4),
      ];
      save.decks['Unowned'] = [
        ...List.filled(1, 'SF002-043'),
        ...save.decks['Mixed']!.skip(1),
      ];
      save.owned['SF002-043'] = 0;
      save.decks['Two legends'] = [
        'SF002-042',
        'SF002-042',
        ...save.decks['Mixed']!.skip(2),
      ];
      save.decks['Three colors'] = [
        'SF002-045',
        'SF002-088',
        ...save.decks['Mixed']!.skip(2),
      ];
      expect(playableOwnedDecks(library, save).keys, ['Mixed']);
    },
  );
  testWidgets('320px story tabs separate campaigns and keep Set 2 locked', (
    tester,
  ) async {
    final save = await profile();
    AudioManager.instance.setSfx(false);
    final ads = AdService(save: save, platform: _NoAds());
    addTearDown(ads.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(library: library, save: save, adService: ads),
      ),
    );
    expect(find.text('SET 1'), findsOneWidget);
    expect(find.text('SET 2'), findsOneWidget);
    expect(find.text(storyChapters.first.title), findsOneWidget);
    expect(find.text(storyChapters[5].title), findsNothing);
    await tester.tap(find.byKey(const ValueKey('story-fiveVows')));
    await tester.pump();
    expect(find.text(storyChapters.first.title), findsNothing);
    expect(find.text(storyChapters[5].title), findsOneWidget);
    await tester.tap(find.text(storyChapters[5].title));
    await tester.pump();
    expect(find.byType(ChapterMapScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('chapter map passes an owned mixed deck into either campaign', (
    tester,
  ) async {
    final save = await profile();
    final deck = BattleDecks.build(library, 'VERDANCE', seed: 19);
    save.owned.addAll({for (final c in deck) c.id: 3});
    save.decks['My two-set deck'] = deck.map((c) => c.id).toList();
    AudioManager.instance.setSfx(false);
    AudioManager.instance.voiceOn = false;
    final ads = AdService(save: save, platform: _NoAds());
    addTearDown(ads.dispose);
    for (final chapter in [storyChapters.first, storyChapters[5]]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: ChapterMapScreen(
            chapter: chapter,
            library: library,
            save: save,
            adService: ads,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('story-deck-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My two-set deck').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BEGIN CHAPTER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final player = tester.widget<ChapterPlayerScreen>(
        find.byType(ChapterPlayerScreen),
      );
      expect(player.playerDeck!.map((c) => c.id), deck.map((c) => c.id));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
