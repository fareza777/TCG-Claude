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
    // enemy itself opens with units on the board. Between battle four and the
    // first of those, the player stands alone.
    //
    // How much comes back is no longer one creature. Measured by playing the
    // fights, a single lent wall left them at 14%, 4% and 0% for a competent
    // player -- and a wall cannot block Dread at all, which needs two units --
    // so each fight now gets the lightest help that makes it fair, up to
    // [maxLent] units in total. See tool/story_calibrate.dart.
    const maxLent = 3;
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
        if (battle.enemyBoardIds.isEmpty) {
          expect(help[i - 1], 0,
              reason: '${chapter.id} battle $i must stand on its own');
          expect(battle.playerHealth, 25,
              reason: '${chapter.id} battle $i has no board to answer, so it '
                  'has no extra Health to offer either');
          expect(battle.playerFirst, isTrue,
              reason: '${chapter.id} battle $i has no reason to move second');
        } else {
          expect(help[i - 1], lessThanOrEqualTo(maxLent),
              reason: '${chapter.id} battle $i lends ${help[i - 1]} units; '
                  'past $maxLent it is an army, not help');
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

  test('every kind of help a fight gives is announced, and agrees', () {
    // The briefing is the only place a player learns they are not alone, or
    // that they start with more Health, or that the foe moves first.
    final lent = RegExp(r'^(One|Two|Three) of .* (stands|stand) with you\.$');
    const words = ['One', 'Two', 'Three'];

    for (final chapter in storyChapters) {
      for (final (i, battle) in battlesOf(chapter).indexed) {
        final where = '${chapter.id} battle ${i + 1}';
        final rules = battle.specialRules;

        if (battle.playerBoardIds.isNotEmpty) {
          final line = rules.where(lent.hasMatch).toList();
          if (line.isEmpty) {
            // The opening fights word it as already standing with you.
            expect(rules.any((r) => r.contains('already stand with you')),
                isTrue,
                reason: '$where lends creatures without saying so');
          } else {
            final count = battle.playerBoardIds.length;
            expect(line.single, startsWith(words[count - 1]),
                reason: '$where lends $count but says "${line.single}"');
          }
        }

        if (battle.playerHealth != 25) {
          expect(rules, contains('You begin with ${battle.playerHealth} '
              'Health.'),
              reason: '$where gives extra Health without saying so');
        }
        if (!battle.playerFirst) {
          expect(rules.any((r) => r.startsWith('The foe takes the first turn')),
              isTrue,
              reason: '$where moves the foe first without saying so');
        }
      }
    }
  });

  test('every number a briefing quotes is the number the fight uses', () {
    // Found by looking: chapter 1 battle 19 said "31 Health" over a fight with
    // 32, and chapter 5 battle 19 said 33. The earlier check only read the
    // opening ten fights, so nothing caught either.
    final health = RegExp(r'(\d+) Health');
    for (final chapter in storyChapters) {
      for (final (i, battle) in battlesOf(chapter).indexed) {
        final where = '${chapter.id} battle ${i + 1}';
        final foes = battle.enemyBoardIds.length;

        for (final line in battle.specialRules) {
          for (final m in health.allMatches(line)) {
            final quoted = int.parse(m.group(1)!);
            if (line.startsWith('You begin with')) {
              expect(quoted, battle.playerHealth, reason: '$where: "$line"');
            } else if (line.startsWith('The foe has')) {
              continue; // "has X Health to your Y." -- checked above
            } else {
              expect(quoted, battle.enemyHealth, reason: '$where: "$line"');
            }
          }
          if (line.contains('two creatures')) {
            expect(foes, 2, reason: '$where says two creatures: "$line"');
          }
          if (RegExp(r'\b(a|one) creature').hasMatch(line)) {
            expect(foes, 1, reason: '$where says one creature: "$line"');
          }
        }
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
