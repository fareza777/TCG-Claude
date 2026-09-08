import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/story_data.dart';

/// The campaign's difficulty ramp, locked down.
///
/// These exist because the original Chapter I opened by handing the enemy a
/// free creature while the player started empty — an unwinnable-feeling tempo
/// race for someone still learning the rules. Content written later must not
/// quietly reintroduce that.
void main() {
  List<StoryBattle> battlesOf(StoryChapter c) =>
      c.stages.where((s) => s.battle != null).map((s) => s.battle!).toList();

  test('every chapter runs twenty battles', () {
    for (final chapter in storyChapters) {
      expect(chapter.battleCount, 20, reason: '${chapter.id} battle count');
    }
  });

  test('the opening five battles of a chapter never favour the enemy', () {
    for (final chapter in storyChapters) {
      final opening = battlesOf(chapter).take(5);
      for (final (i, battle) in opening.indexed) {
        final where = '${chapter.id} battle ${i + 1} (${battle.enemyName})';
        expect(battle.enemyBoardIds, isEmpty,
            reason: '$where must not start the foe with a board');
        expect(battle.hardAi, isFalse,
            reason: '$where must use the gentler AI');
        expect(battle.enemyHealth, lessThanOrEqualTo(battle.playerHealth),
            reason: '$where must not out-Health the player');
      }
    }
  });

  test('the first battle is a pure tutorial', () {
    for (final chapter in storyChapters) {
      final first = battlesOf(chapter).first;
      expect(first.playerBoardIds.length, greaterThanOrEqualTo(2),
          reason: '${chapter.id} battle 1 should open with two creatures '
              'already in play');
    }
  });

  test('help tapers off, and only returns to answer a board', () {
    // The original curve handed out two free creatures for five straight
    // fights and only withdrew help at battle eleven, which reads as being
    // led by the hand through half a chapter. Help must shrink every step and
    // be gone by battle four.
    //
    // It comes back later, but never as a gift: only in the fights where the
    // enemy itself opens with two units, and never more than one. Between
    // battle four and the first of those, the player stands alone.
    for (final chapter in storyChapters) {
      final battles = battlesOf(chapter);
      final help = [for (final b in battles) b.playerBoardIds.length];

      for (var i = 1; i <= 3; i++) {
        expect(help[i - 1], greaterThanOrEqualTo(1),
            reason: '${chapter.id} battle $i should still offer some help');
      }
      for (var i = 1; i < 3; i++) {
        expect(help[i], lessThanOrEqualTo(help[i - 1]),
            reason: '${chapter.id} battle ${i + 1} hands out more help than '
                'the fight before it');
      }

      for (var i = 4; i <= help.length; i++) {
        final battle = battles[i - 1];
        if (battle.enemyBoardIds.length >= 2) {
          expect(help[i - 1], 1,
              reason: '${chapter.id} battle $i answers two enemy creatures '
                  'with ${help[i - 1]} — it should be exactly one');
        } else {
          expect(help[i - 1], 0,
              reason: '${chapter.id} battle $i must stand on its own');
        }
      }
    }
  });

  test('the briefing text agrees with the scenario it describes', () {
    // The rules shown before a fight are generated from the real numbers for
    // the opening ten, so a mismatch means someone hand-edited one of them.
    for (final chapter in storyChapters) {
      for (final (i, battle) in battlesOf(chapter).take(10).indexed) {
        final where = '${chapter.id} battle ${i + 1}';
        expect(battle.specialRules, contains(
            'The foe has ${battle.enemyHealth} Health to your '
            '${battle.playerHealth}.'),
            reason: '$where does not state its own Health totals');
        if (battle.playerBoardIds.length == 1) {
          expect(battle.specialRules.any((r) => r.startsWith('One of ')), isTrue,
              reason: '$where gives one creature but does not say so');
        }
      }
    }
  });

  test('the player is never sent in empty against two', () {
    // A player wrote in stuck on chapter 1 battle 17. Every chapter had the
    // same shape from battle 16: the enemy opened with two units and 29+
    // Health while the player had an empty board, 25 Health and a starter
    // deck they cannot change. Losing tempo and stats at once, with no answer
    // available, is not difficulty -- it is a wall.
    for (final chapter in storyChapters) {
      for (final (i, battle) in battlesOf(chapter).indexed) {
        if (battle.enemyBoardIds.length < 2) continue;
        expect(battle.playerBoardIds, isNotEmpty,
            reason: '${chapter.id} battle ${i + 1} puts two creatures across '
                'the table and gives the player none');
      }
    }
  });

  test('a lent creature is always announced', () {
    // The briefing is the only place a player learns they are not alone.
    for (final chapter in storyChapters) {
      for (final (i, battle) in battlesOf(chapter).indexed) {
        if (battle.playerBoardIds.isEmpty) continue;
        expect(battle.specialRules.any((r) => r.contains('stands with you') ||
                r.contains('already stand with you')), isTrue,
            reason: '${chapter.id} battle ${i + 1} lends a creature without '
                'saying so');
      }
    }
  });

  test('difficulty only ever climbs across a chapter', () {
    for (final chapter in storyChapters) {
      final health = battlesOf(chapter).map((b) => b.enemyHealth).toList();
      for (var i = 1; i < health.length; i++) {
        expect(health[i], greaterThanOrEqualTo(health[i - 1]),
            reason: '${chapter.id} battle ${i + 1} drops below the fight '
                'before it — the ramp must be monotonic');
      }
    }
  });

  test('the last battle of a chapter is the hardest fight in it', () {
    for (final chapter in storyChapters) {
      final battles = battlesOf(chapter);
      final boss = battles.last;
      expect(boss.hardAi, isTrue, reason: '${chapter.id} boss needs the '
          'smarter AI');
      expect(boss.enemyHealth,
          greaterThan(battles[battles.length - 2].enemyHealth),
          reason: '${chapter.id} boss must outclass the fight before it');
    }
  });

  test('every story beat points at art that ships with the app', () {
    // Guards against a beat referencing an asset nobody generated.
    for (final chapter in storyChapters) {
      for (final stage in chapter.stages) {
        final beat = stage.beat;
        if (beat == null) continue;
        expect(beat.artAsset, startsWith('STORY-${chapter.id}-'),
            reason: '${chapter.id} beat "${beat.title}" uses a foreign asset');
      }
    }
  });
}
