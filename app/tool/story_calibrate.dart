// Finds the lightest help that makes each "enemy opens with units" fight fair.
//
// Run from app/:  dart run tool/story_calibrate.dart --out=plan.json [flags]
//
//   --games=N       seeds per step                              (default 60)
//   --chapter=N     one chapter, 1-5                            (default: all)
//   --target=F      win rate a fight must reach, non-boss       (default 0.42)
//   --boss19=F      ... the first boss                          (default 0.27)
//   --boss20=F      ... the chapter finale                      (default 0.22)
//
// Why this exists. Fights where the enemy opens with units were measured at
// 14% (one unit), 4% (two) and 0% (bosses) for a competent player, and the
// same recipe does not fix every chapter: Health barely moves chapters 3 and
// 4 but swings chapter 5 from 10% to 57%; a lent wall is useless against Dread
// (it must be blocked by two units); the chapter-finale bosses stay near 0%
// whatever the player is given. A single rule tuned by hand would leave some
// chapters walled and make others trivial.
//
// So each fight is offered every combination of help, and takes the cheapest
// one at which the Tactician reaches the target:
//
//   Health         +0, +5, +10 or +15            cost 1 per +5
//   the enemy loses its second unit              cost 2
//   lent units     up to two light (cost 1 each) and one heavy (cost 2)
//   the player moves second                      cost 4
//
// The costs say how much each kind of help changes the fight, and they stop a
// large help being reached for when a small one would do. The first version of
// this was a ladder taken in order; it overshot badly (a fight at 25% jumped
// to 87% on one rung and could not step back), because a ladder cannot skip a
// rung it has already climbed past. A search over combinations can.
//
// The enemy never loses its LAST unit (the fight stays what it was), and the
// finale's Health is first capped at 34 + chapter - 1, so the finales still
// climb from chapter to chapter and still outclass the fight before them.
//
// Choosing a combination on one set of seeds and checking it on another keeps a
// change that passed by luck from passing the check by the same luck: run
// story_sim.dart afterwards, which uses its own.
import 'dart:convert';
import 'dart:io';

import 'package:shardfall/story/story_data.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'story_runner.dart';

/// The units each chapter can lend besides its defender: a light one for a
/// small step and a heavy one for a large step. Every one is a card from that
/// chapter's own starter deck. The first version had only the heavy kind, and
/// a fight sitting at 25% jumped to 87% the moment it was lent -- nothing sat
/// between "no help" and "a monster".
const _lights = [
  'SF001-001', // ch1 Sylvaris Sproutling 1/2
  'SF001-021', // ch2 Cinder Imp 2/1
  'SF001-041', // ch3 Skyfin Scout 1/2 soar
  'SF001-061', // ch4 Dawnlit Recruit 1/2
  'SF001-081', // ch5 Hollow Rat 1/1 venom
];
const _heavies = [
  'SF001-002', // ch1 Thornhide Boar 3/2
  'SF001-022', // ch2 Ashblade Raider 3/1 rush (Berserker 4/2 jumped 25% to 87%)
  'SF001-044', // ch3 Current Rider 3/3 soar
  'SF001-065', // ch4 Lightbringer Vanguard 4/4
  'SF001-082', // ch5 Duskblade Cutthroat 3/2
];

/// The most units a fight may lend the player in total, defenders included.
const maxLent = 3;

/// One way of helping the player in a fight.
class _Combo {
  final int healthSteps; // each +5
  final bool dropSecond;
  final int lights;
  final int heavies;
  final bool moveSecond;

  const _Combo(this.healthSteps, this.dropSecond, this.lights, this.heavies,
      this.moveSecond);

  int get cost =>
      healthSteps +
      (dropSecond ? 2 : 0) +
      lights +
      heavies * 2 +
      (moveSecond ? 4 : 0);

  String get label => [
        if (healthSteps > 0) 'health+${healthSteps * 5}',
        if (dropSecond) 'foe-second-unit',
        if (lights > 0) 'light x$lights',
        if (heavies > 0) 'heavy x$heavies',
        if (moveSecond) 'move-second',
      ].join(' > ');

  /// Null when the combination does nothing to this setup.
  Setup? applyTo(Setup base, String light, String heavy) {
    if (dropSecond && base.enemyBoard.length < 2) return null;
    // Three lent units is a squad; more is an army walking in beside you.
    if (base.playerBoard.length + lights + heavies > maxLent) return null;
    return base.copyWith(
      playerHealth: base.playerHealth + healthSteps * 5,
      enemyBoard: dropSecond
          ? base.enemyBoard.sublist(0, base.enemyBoard.length - 1)
          : base.enemyBoard,
      playerBoard: [
        ...base.playerBoard,
        for (var i = 0; i < lights; i++) light,
        for (var i = 0; i < heavies; i++) heavy,
      ],
      playerSecond: moveSecond ? true : base.playerSecond,
    );
  }
}

/// Every combination, cheapest first; equal costs keep a fixed order so a run
/// is reproducible.
final List<_Combo> _combos = [
  for (var h = 0; h <= 3; h++)
    for (final drop in [false, true])
      for (var l = 0; l <= 2; l++)
        for (var hv = 0; hv <= 1; hv++)
          for (final second in [false, true]) _Combo(h, drop, l, hv, second),
]..sort((a, b) {
    final byCost = a.cost.compareTo(b.cost);
    if (byCost != 0) return byCost;
    return a.label.compareTo(b.label);
  });

double _flag(Map<String, String> f, String k, double d) =>
    double.parse(f[k] ?? '$d');

void main(List<String> args) {
  final flags = <String, String>{
    for (final a in args.where((a) => a.startsWith('--')))
      a.substring(2).split('=').first:
          a.contains('=') ? a.split('=').skip(1).join('=') : 'true',
  };
  final games = int.parse(flags['games'] ?? '60');
  final only =
      flags.containsKey('chapter') ? int.parse(flags['chapter']!) : null;
  final target = _flag(flags, 'target', 0.42);
  final boss19 = _flag(flags, 'boss19', 0.27);
  final boss20 = _flag(flags, 'boss20', 0.22);
  final outPath = flags['out'];

  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  final plan = <Map<String, Object?>>[];

  for (var c = 0; c < storyChapters.length; c++) {
    if (only != null && only != c + 1) continue;
    final chapter = storyChapters[c];
    final light = _lights[c];
    final heavy = _heavies[c];

    var n = 0;
    for (final stage in chapter.stages) {
      final battle = stage.battle;
      if (battle == null) continue;
      n++;
      if (battle.enemyBoardIds.isEmpty) continue;

      final goal = n == 20 ? boss20 : (n == 19 ? boss19 : target);

      var setup = Setup.of(battle);
      if (n == 20) {
        final cap = 34 + c;
        if (setup.enemyHealth > cap) setup = setup.copyWith(enemyHealth: cap);
      }

      double rate(Setup s) => winRate(
            library: library,
            chapter: chapter,
            battle: battle,
            setup: s,
            playerSkill: AiTier.tactician,
            games: games,
          );

      final tried = <double>[];
      Setup? chosen;
      _Combo? chosenCombo;
      var best = 0.0;
      var hit = false;

      for (final combo in _combos) {
        final candidate = combo.applyTo(setup, light, heavy);
        if (candidate == null) continue;
        final r = rate(candidate);
        tried.add(r);
        // Keep the strongest seen, for a fight no combination fixes.
        if (chosen == null || r > best) {
          chosen = candidate;
          chosenCombo = combo;
          best = r;
        }
        if (r >= goal) {
          chosen = candidate;
          chosenCombo = combo;
          best = r;
          hit = true;
          break;
        }
      }

      setup = chosen!;
      final applied = chosenCombo!.cost == 0 ? <String>[] : [chosenCombo.label];

      stdout.writeln('ch${c + 1} #${n.toString().padLeft(2)}  '
          '${hit ? "ok  " : "MISS"}  '
          '${(best * 100).round().toString().padLeft(3)}%'
          '  (goal ${(goal * 100).round()}%, tried ${tried.length})  '
          '${applied.isEmpty ? "unchanged" : applied.join(" > ")}');

      plan.add({
        'chapter': c + 1,
        'battle': n,
        'hit': hit,
        'rate': best,
        'goal': goal,
        'applied': applied,
        'playerHealth': setup.playerHealth,
        'enemyHealth': setup.enemyHealth,
        'enemyBoard': setup.enemyBoard,
        'playerBoard': setup.playerBoard,
        'playerSecond': setup.playerSecond,
        'tried': tried,
      });
    }
  }

  if (outPath != null) {
    File(outPath)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(plan));
    stdout.writeln('\nwrote $outPath');
  }
  final misses = plan.where((p) => p['hit'] == false).length;
  stdout.writeln('$misses of ${plan.length} fights still short of their goal.');
}
