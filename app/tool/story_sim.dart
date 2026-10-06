// Plays every story battle headlessly and reports how often the player wins.
//
// Run from app/:  dart run tool/story_sim.dart [flags]
//
//   --games=N       seeds per battle and per player skill      (default 40)
//   --chapter=N     one chapter, 1-5                           (default: all)
//   --skills=a,b    greedy and/or tactician                    (default: both)
//   --onboard       only play the fights where the enemy opens with units
//   --seed=N        first seed (default 1000; story_calibrate.dart picks help
//                   on 1000, so check a change on a different one)
//
// The campaign's difficulty used to be judged by a hand-made score (enemy
// Health over yours, plus six per creature on the board). That ranks battles
// but cannot say whether one is winnable, and it cannot be compared across a
// change. This plays them.
//
// Two skills are reported because the real player is neither: Greedy (plays
// its most expensive card, attacks freely) is the floor; Tactician (weighs a
// trade before attacking) is a competent player. Measured against the
// telemetry of real players on chapter 1, the Tactician's win rate tracks
// theirs battle for battle, which is what makes this worth trusting.
//
// To try a change before writing it into a chapter, use story_calibrate.dart.
import 'dart:io';

import 'package:shardfall/story/story_data.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'story_runner.dart';

String _pct(num fraction) => '${(100 * fraction).round()}%';

int _intFlag(Map<String, String> flags, String name, int fallback) =>
    int.parse(flags[name] ?? '$fallback');

void main(List<String> args) {
  final flags = <String, String>{
    for (final a in args.where((a) => a.startsWith('--')))
      a.substring(2).split('=').first:
          a.contains('=') ? a.split('=').skip(1).join('=') : 'true',
  };
  final games = _intFlag(flags, 'games', 40);
  final only =
      flags.containsKey('chapter') ? _intFlag(flags, 'chapter', 0) : null;
  final onlyOnboard = flags.containsKey('onboard');
  final seedBase = _intFlag(flags, 'seed', 1000);
  final skills = [
    for (final name in (flags['skills'] ?? 'greedy,tactician').split(','))
      AiTier.values.byName(name.trim()),
  ];

  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  final head = StringBuffer('${"ch".padLeft(3)} ${"#".padLeft(3)} '
      '${"foeHP".padLeft(6)} ${"you".padLeft(4)} ${"foe".padLeft(4)} '
      '${"help".padLeft(5)} ${"boss".padLeft(5)} ${"2nd".padLeft(4)} ');
  for (final s in skills) {
    head.write(s.name.substring(0, 6).padLeft(8));
  }
  stdout.writeln(head);
  stdout.writeln('-' * (40 + 8 * skills.length));

  // Win rate per band, across every chapter, for the summary.
  final bands = <String, List<double>>{
    'battles 4-12 (no enemy units)': [],
    'battles 13-15 (one enemy unit)': [],
    'battles 16-18 (two enemy units)': [],
    'battles 19-20 (bosses)': [],
  };
  String bandOf(int n, StoryBattle b) {
    if (b.enemyBoardIds.isEmpty && n >= 4) {
      return 'battles 4-12 (no enemy units)';
    }
    if (n >= 19) return 'battles 19-20 (bosses)';
    if (n >= 16) return 'battles 16-18 (two enemy units)';
    if (n >= 13) return 'battles 13-15 (one enemy unit)';
    return '';
  }

  for (var c = 0; c < storyChapters.length; c++) {
    if (only != null && only != c + 1) continue;
    final chapter = storyChapters[c];

    var n = 0;
    for (final stage in chapter.stages) {
      final battle = stage.battle;
      if (battle == null) continue;
      n++;
      if (onlyOnboard && battle.enemyBoardIds.isEmpty) continue;

      final rates = <AiTier, double>{
        for (final skill in skills)
          skill: winRate(
            library: library,
            chapter: chapter,
            battle: battle,
            setup: Setup.of(battle),
            playerSkill: skill,
            games: games,
            seedBase: seedBase,
          ),
      };

      final row = StringBuffer('${"${c + 1}".padLeft(3)} ${"$n".padLeft(3)} '
          '${"${battle.enemyHealth}".padLeft(6)} '
          '${"${battle.playerHealth}".padLeft(4)} '
          '${"${battle.enemyBoardIds.length}".padLeft(4)} '
          '${"${battle.playerBoardIds.length}".padLeft(5)} '
          '${(battle.hardAi ? "yes" : "").padLeft(5)} '
          '${(battle.playerFirst ? "" : "yes").padLeft(4)} ');
      for (final s in skills) {
        row.write(_pct(rates[s]!).padLeft(8));
      }
      stdout.writeln(row);

      final band = bandOf(n, battle);
      if (band.isNotEmpty) {
        bands[band]!.add(rates[AiTier.tactician] ?? rates.values.first);
      }
    }
    stdout.writeln();
  }

  final label =
      skills.contains(AiTier.tactician) ? 'tactician' : skills.first.name;
  stdout.writeln('average win rate by band ($label):');
  for (final e in bands.entries) {
    if (e.value.isEmpty) continue;
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    stdout.writeln('  ${e.key.padRight(34)} ${_pct(avg).padLeft(5)}'
        '   (${e.value.map(_pct).join(" ")})');
  }
}
