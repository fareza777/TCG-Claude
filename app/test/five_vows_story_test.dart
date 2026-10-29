import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/narration.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shardfall/story/vow_encounters.dart';
import 'package:shardfall/story/campaign_progress.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/duel/scenario.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  test('Five Vows appends twenty complete chapters after original five', () {
    expect(storyChapters.take(5).map((c) => c.id), [
      'ch1',
      'ch2',
      'ch3',
      'ch4',
      'ch5',
    ]);
    final expansion = storyChapters.skip(5).toList();
    expect(expansion.map((c) => c.id), [
      for (var i = 1; i <= 20; i++) 'vow${i.toString().padLeft(2, '0')}',
    ]);
    for (final chapter in expansion) {
      expect(chapter.battleCount, inInclusiveRange(2, 3));
      expect(
        chapter.stages.where((s) => s.beat != null).length,
        greaterThanOrEqualTo(4),
      );
      for (final battle
          in chapter.stages
              .where((s) => s.battle != null)
              .map((s) => s.battle!)) {
        expect(battle.preBattle, isNotEmpty);
        expect(battle.victory, isNotEmpty);
      }
      expect(
        Narration.all().where((c) => c.chapterId == chapter.id).length,
        greaterThanOrEqualTo(25),
      );
    }
  });

  test(
    'home continuation follows progress into and through The Five Vows',
    () async {
      SharedPreferences.setMockInitialValues({'gold': 120});
      final save = await SaveService.load(library);
      expect(nextStoryChapter(save)?.id, 'ch1');
      save.chaptersDone.addAll(['ch1', 'ch2', 'ch3', 'ch4', 'ch5']);
      expect(nextStoryChapter(save)?.id, 'vow01');
      save.chaptersDone.add('vow01');
      expect(nextStoryChapter(save)?.id, 'vow02');
      save.chaptersDone.addAll(storyChapters.map((chapter) => chapter.id));
      expect(nextStoryChapter(save), isNull);
    },
  );

  test(
    'forty encounters use legal, playable SF002 loan decks and fair boards',
    () {
      var count = 0;
      for (final chapter in storyChapters.skip(5)) {
        for (final battle
            in chapter.stages.map((s) => s.battle).whereType<StoryBattle>()) {
          count++;
          expect(battle.deckSetCode, 'SF002');
          for (final dom in [chapter.playerDominion, battle.enemyDominion]) {
            final deck = storyDeck(
              library,
              dom,
              setCode: battle.deckSetCode,
              variant: battle.deckVariant,
            );
            expect(deck, hasLength(40));
            expect(deck.every((c) => c.id.startsWith('SF002-')), isTrue);
            expect(
              deck.where((c) => c.type == CardType.wellspring),
              hasLength(16),
            );
            expect(
              deck.where((c) => c.type == CardType.unit).length,
              greaterThanOrEqualTo(15),
            );
            expect(
              deck
                  .where((c) => c.type == CardType.unit)
                  .any((c) => c.totalCost <= 2),
              isTrue,
            );
            expect(
              deck.any((c) => c.effects.any((e) => e['trigger'] == 'ON_VOW')),
              isTrue,
            );
          }
          final allies = battle.playerBoardIds.map(library.card).toList();
          final enemies = battle.enemyBoardIds.map(library.card).toList();
          expect(
            [...allies, ...enemies].every((c) => c.type == CardType.unit),
            isTrue,
          );
          expect(battle.playerHealth, greaterThan(0));
          expect(battle.enemyHealth, greaterThan(0));
          expect(
            enemies.fold<int>(0, (n, c) => n + c.might!),
            lessThan(battle.playerHealth),
          );
          expect(
            battle.specialRules,
            contains(
              'The foe has ${battle.enemyHealth} Health to your ${battle.playerHealth}.',
            ),
          );
          final controller = DuelController(
            playerDeck: storyDeck(
              library,
              chapter.playerDominion,
              setCode: battle.deckSetCode,
              variant: battle.deckVariant,
            ),
            enemyDeck: storyDeck(
              library,
              battle.enemyDominion,
              setCode: battle.deckSetCode,
              variant: battle.deckVariant + 1,
            ),
            seed: count,
            firstPlayer: battle.playerFirst ? PlayerId.p1 : PlayerId.p2,
            scenario: BattleScenario(
              playerHealth: battle.playerHealth,
              enemyHealth: battle.enemyHealth,
              playerBoard: allies,
              enemyBoard: enemies,
            ),
          );
          expect(controller.me.health, battle.playerHealth);
          expect(
            controller.me.arena.map((c) => c.def.id),
            battle.playerBoardIds,
          );
          expect(controller.isGameOver, isFalse);
          controller.dispose();
        }
      }
      expect(count, 40);
    },
  );

  test(
    'expansion unlock, persisted resume and replay rewards are safe',
    () async {
      SharedPreferences.setMockInitialValues({});
      var save = await SaveService.load(library);
      expect(storyChapterUnlocked(5, save), isFalse);
      await save.completeChapter('ch5');
      expect(storyChapterUnlocked(5, save), isTrue);
      expect(storyChapterUnlocked(6, save), isFalse);
      await save.setChapterStage('vow01', 3);
      save = await SaveService.load(library);
      expect(save.stageOf('vow01'), 3);
      await save.setChapterStage('vow01', 1);
      expect(save.stageOf('vow01'), 3);
      final earned = await rewardCampaignBattle(
        save,
        'vow01',
        2,
        freePlay: false,
      );
      expect(earned, SaveService.storyFirstClearGold);
      final gold = save.gold;
      for (var i = 0; i < 3; i++) {
        expect(await rewardCampaignBattle(save, 'vow01', 2, freePlay: true), 0);
      }
      expect(save.gold, gold);
      expect(await save.completeChapter('vow01'), greaterThan(0));
      final completedGold = save.gold;
      expect(await save.completeChapter('vow01'), 0);
      expect(save.gold, completedGold);
      expect(storyChapterUnlocked(6, save), isTrue);
      expect(storyChapterUnlocked(7, save), isFalse);
    },
  );

  test('narration export exactly matches positional runtime clips', () {
    final manifest =
        jsonDecode(
              File('../tools/voice_pipeline/narration.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final exported = {for (final c in manifest['clips'] as List) c['id']: c};
    for (final clip in Narration.all()) {
      expect(exported[clip.id]?['text'], clip.text, reason: clip.id);
      expect(exported[clip.id]?['voiceKey'], clip.voiceKey, reason: clip.id);
    }
    expect(exported.length, Narration.all().length);
  });
}
