import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/story_difficulty.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../tool/story_runner.dart';

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);

  StoryBattle battleAt(StoryChapter chapter, int number) => chapter.stages
      .map((s) => s.battle)
      .whereType<StoryBattle>()
      .elementAt(number - 1);

  test('the audit records reproducible completed turns and a real winner', () {
    final chapter = storyChapters.first;
    final battle = battleAt(chapter, 1);
    final a = playBattleDetailed(
      library: library,
      chapter: chapter,
      battle: battle,
      setup: Setup.of(battle),
      playerSkill: AiTier.tactician,
      seed: 2026102907,
    );
    expect(a.playerWon, isNotNull);
    expect(a.turns, greaterThan(0));
    expect(a.stalled, isFalse);
    expect(
      playBattle(
        library: library,
        chapter: chapter,
        battle: battle,
        setup: Setup.of(battle),
        playerSkill: AiTier.tactician,
        seed: 2026102907,
      ),
      a.playerWon,
    );
  });

  test(
    'calibration preserves stage positions, narrative and enemy identity',
    () {
      expect(storyChapters.length, authoredStoryChapters.length);
      for (var c = 0; c < storyChapters.length; c++) {
        final original = authoredStoryChapters[c];
        final tuned = storyChapters[c];
        expect(tuned.id, original.id);
        expect(tuned.title, original.title);
        expect(tuned.subtitle, original.subtitle);
        expect(tuned.playerDominion, original.playerDominion);
        expect(tuned.stages.length, original.stages.length);
        for (var s = 0; s < original.stages.length; s++) {
          expect(tuned.stages[s].beat, same(original.stages[s].beat));
          final before = original.stages[s].battle;
          final after = tuned.stages[s].battle;
          if (before == null) {
            expect(after, isNull);
            continue;
          }
          expect(after, isNotNull);
          expect(after!.enemyName, before.enemyName);
          expect(after.enemyDominion, before.enemyDominion);
          expect(after.enemyBoardIds, before.enemyBoardIds);
          expect(after.deckSetCode, before.deckSetCode);
          expect(after.deckVariant, before.deckVariant);
          expect(after.hardAi, before.hardAi);
          expect(after.preBattle, same(before.preBattle));
          expect(after.victory, same(before.victory));
          expect(after.objective, before.objective);
          expect(after.playerBoardIds.length, lessThanOrEqualTo(3));
        }
      }
    },
  );

  test('every encounter briefing states actual health, boards and first seat', () {
    var seen = 0;
    for (final chapter in storyChapters) {
      var number = 0;
      for (final stage in chapter.stages) {
        final battle = stage.battle;
        if (battle == null) continue;
        number++;
        seen++;
        final where = '${chapter.id}.$number';
        final rules = battle.specialRules;
        expect(
          rules,
          contains(
            'The foe has ${battle.enemyHealth} Health '
            'to your ${battle.playerHealth}.',
          ),
          reason: where,
        );
        expect(
          rules,
          contains(
            battle.playerFirst
                ? 'You take the first turn.'
                : 'The foe takes the first turn. You draw an extra opening card.',
          ),
          reason: where,
        );
        if (battle.playerBoardIds.isEmpty) {
          expect(
            rules,
            contains('You begin with an empty board.'),
            reason: where,
          );
        } else {
          const counts = ['One', 'Two', 'Three'];
          final count = battle.playerBoardIds.length;
          expect(
            rules,
            contains(
              '${counts[count - 1]} of your allies '
              '${count == 1 ? 'stands' : 'stand'} with you.',
            ),
            reason: where,
          );
        }
        final count = battle.enemyBoardIds.length;
        expect(
          rules,
          contains(
            count == 0
                ? 'The enemy begins with an empty board.'
                : 'The enemy opens with ${count == 1 ? 'one creature' : '$count creatures'} in play.',
          ),
          reason: where,
        );
      }
    }
    expect(seen, 140);
  });

  test('an unaided Pyre opening does not become a campaign wall', () {
    final chapter = storyChapters[1];
    final battle = battleAt(chapter, 6);
    final rate = winRate(
      library: library,
      chapter: chapter,
      battle: battle,
      setup: Setup.of(battle),
      playerSkill: AiTier.tactician,
      games: 40,
      seedBase: 2026102907,
    );
    expect(rate, inInclusiveRange(0.4, 0.85));
  });

  test('the ongoing Five Vows campaign requires a contested duel', () {
    final chapter = storyChapters.firstWhere((c) => c.id == 'vow15');
    final battle = battleAt(chapter, 1);
    final rate = winRate(
      library: library,
      chapter: chapter,
      battle: battle,
      setup: Setup.of(battle),
      playerSkill: AiTier.tactician,
      games: 40,
      seedBase: 2026102907,
    );
    expect(rate, inInclusiveRange(0.35, 0.8));
  });

  test(
    'all 140 runtime encounters avoid trivial or punishing seeded outcomes',
    () {
      final outliers = <String>[];
      var count = 0;
      for (final chapter in storyChapters) {
        var number = 0;
        for (final battle
            in chapter.stages.map((s) => s.battle).whereType<StoryBattle>()) {
          number++;
          count++;
          final band = storyDifficultyBand(chapter.id, number);
          final rate = winRate(
            library: library,
            chapter: chapter,
            battle: battle,
            setup: Setup.of(battle),
            playerSkill: AiTier.tactician,
            games: 40,
            seedBase: 2026102907,
          );
          // A fast regression envelope allows sampling noise. The full audit
          // uses 100 per skill and all three disjoint seed sets, retaining
          // individual outcomes and narrower intended bands in its report.
          final (lower, upper) = switch (band) {
            StoryDifficultyBand.onboarding => (.60, 1.0),
            StoryDifficultyBand.ordinary => (.35, .85),
            StoryDifficultyBand.challenge => (.30, .75),
          };
          if (rate < lower || rate > upper) {
            outliers.add('${chapter.id}.$number ${band.name}: $rate');
          }
        }
      }
      expect(count, 140);
      expect(outliers, isEmpty);
    },
  );

  test(
    'each original chapter finale is measurably harder than its tutorial',
    () {
      for (final chapter in storyChapters.take(5)) {
        double rate(int number) {
          final battle = battleAt(chapter, number);
          return winRate(
            library: library,
            chapter: chapter,
            battle: battle,
            setup: Setup.of(battle),
            playerSkill: AiTier.tactician,
            games: 100,
            seedBase: 2026102907,
          );
        }

        expect(rate(1) - rate(20), greaterThan(.15), reason: chapter.id);
      }
    },
  );
}
