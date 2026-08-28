import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/gauntlet/gauntlet_reward.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// One attempt a day is the rule the whole mode rests on. If it can be
/// re-rolled the leaderboard is meaningless, and if a battery dying costs the
/// player their attempt they will not come back tomorrow. Both edges are here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const library = CardLibrary(byId: {}, starterDecks: {});

  Future<SaveService> freshSave() async {
    SharedPreferences.setMockInitialValues({});
    return SaveService.load(library);
  }

  group('the attempt', () {
    test('is not spent until it is finished', () async {
      final save = await freshSave();
      await save.beginGauntlet('2026-09-01');

      expect(save.gauntletDoneFor('2026-09-01'), isFalse);
      expect(save.gauntletResumableFor('2026-09-01'), isTrue,
          reason: 'a closed app must be resumable, not forfeited');
    });

    test('is spent once it is finished', () async {
      final save = await freshSave();
      await save.beginGauntlet('2026-09-01');
      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: true,
          healthLeft: 12,
          turns: 9,
          gold: 120,
          shards: 20);

      expect(save.gauntletDoneFor('2026-09-01'), isTrue);
      expect(save.gauntletResumableFor('2026-09-01'), isFalse);
    });

    test('cannot be banked twice', () async {
      // Otherwise finishing, backing out and re-entering pays again.
      final save = await freshSave();
      await save.beginGauntlet('2026-09-01');
      final before = save.gold;

      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: true,
          healthLeft: 10,
          turns: 8,
          gold: 200,
          shards: 40);
      final afterFirst = save.gold;

      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: true,
          healthLeft: 10,
          turns: 8,
          gold: 200,
          shards: 40);

      expect(afterFirst, before + 200);
      expect(save.gold, afterFirst, reason: 'the second bank must pay nothing');
    });

    test('a new day opens a new attempt', () async {
      final save = await freshSave();
      await save.beginGauntlet('2026-09-01');
      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: false,
          healthLeft: 0,
          turns: 11,
          gold: 40,
          shards: 0);

      expect(save.gauntletDoneFor('2026-09-02'), isFalse);
    });
  });

  group('the streak', () {
    Future<SaveService> playing(List<String> days) async {
      final save = await freshSave();
      for (final day in days) {
        await save.beginGauntlet(day);
        await save.finishGauntlet(
            dayId: day,
            won: true,
            healthLeft: 10,
            turns: 9,
            gold: 0,
            shards: 0);
      }
      return save;
    }

    test('climbs on consecutive days', () async {
      final save =
          await playing(['2026-09-01', '2026-09-02', '2026-09-03']);
      expect(save.gauntletStreak, 3);
    });

    test('counts a loss as a day played', () async {
      // The streak is about turning up. Punishing a loss twice -- no reward
      // and a broken streak -- teaches players to skip the hard days.
      final save = await freshSave();
      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: true,
          healthLeft: 9,
          turns: 9,
          gold: 0,
          shards: 0);
      await save.finishGauntlet(
          dayId: '2026-09-02',
          won: false,
          healthLeft: 0,
          turns: 12,
          gold: 0,
          shards: 0);

      expect(save.gauntletStreak, 2);
    });

    test('resets after a missed day', () async {
      final save = await playing(['2026-09-01', '2026-09-02', '2026-09-05']);
      expect(save.gauntletStreak, 1);
    });

    test('cannot be farmed twice in one day', () async {
      final save = await playing(['2026-09-01']);
      await save.finishGauntlet(
          dayId: '2026-09-01',
          won: true,
          healthLeft: 10,
          turns: 9,
          gold: 0,
          shards: 0);

      expect(save.gauntletStreak, 1);
    });

    test('survives a month boundary', () async {
      final save = await playing(['2026-09-29', '2026-09-30', '2026-10-01']);
      expect(save.gauntletStreak, 3,
          reason: 'the 1st follows the 30th; a naive day-number compare would '
              'break the streak here');
    });
  });

  group('scoring', () {
    test('a loss still pays for turning up', () {
      final r = GauntletScoring.score(won: false, healthLeft: 0, turns: 12);

      expect(r.gold, GauntletScoring.completionGold);
      expect(r.gold, greaterThan(0));
      expect(r.lines, isNotEmpty);
    });

    test('a win pays more than a loss', () {
      final loss = GauntletScoring.score(won: false, healthLeft: 0, turns: 12);
      final win = GauntletScoring.score(won: true, healthLeft: 3, turns: 12);

      expect(win.gold, greaterThan(loss.gold));
      expect(win.shards, greaterThan(loss.shards));
    });

    test('the thresholds stack, and only on a win', () {
      final scrappy =
          GauntletScoring.score(won: true, healthLeft: 2, turns: 14);
      final clean = GauntletScoring.score(
          won: true, healthLeft: GauntletScoring.cleanHealth, turns: 14);
      final perfect = GauntletScoring.score(
          won: true,
          healthLeft: GauntletScoring.cleanHealth,
          turns: GauntletScoring.swiftTurns);

      expect(clean.gold, greaterThan(scrappy.gold));
      expect(perfect.gold, greaterThan(clean.gold));

      // A fast loss must not collect the speed bonus.
      final fastLoss =
          GauntletScoring.score(won: false, healthLeft: 0, turns: 3);
      expect(fastLoss.gold, GauntletScoring.completionGold);
    });

    test('milestones land only on their exact day', () {
      expect(GauntletScoring.streakBonus(3).gold, greaterThan(0));
      expect(GauntletScoring.streakBonus(4).gold, 0);
      expect(GauntletScoring.streakBonus(7).gold, greaterThan(0));
      expect(GauntletScoring.streakBonus(30).gold, greaterThan(0));
    });

    test('the next milestone is always ahead, until there are none', () {
      for (final streak in [0, 1, 2, 3, 6, 13, 29]) {
        final next = GauntletScoring.nextMilestone(streak);
        expect(next, isNotNull, reason: 'at $streak');
        expect(next, greaterThan(streak));
      }
      expect(GauntletScoring.nextMilestone(30), isNull);
      expect(GauntletScoring.nextMilestone(99), isNull);
    });
  });
}
