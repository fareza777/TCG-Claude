// Reproducible audit of every actual Story encounter, including loan decks.
// From app/: dart run tool/campaign_difficulty_audit.dart --games=100
// --seed=2026102907 --out=../docs/expansion/story-difficulty-0.2.2/reference.json
// --authored preserves the untouched authored baseline. --chapters=ch1,vow01
// can bound a smoke run. Final evidence always covers the complete campaign.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/story_difficulty.dart';
import 'package:shardfall/story/vow_encounters.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'story_runner.dart';

const campaignSeedStride = 37;

Map<String, String> auditFlags(List<String> args) => {
  for (final arg in args.where((a) => a.startsWith('--')))
    arg.substring(2).split('=').first: arg.contains('=')
        ? arg.split('=').skip(1).join('=')
        : 'true',
};

CardLibrary campaignLibrary() => CardLibrary.fromJsonStrings([
  File('assets/data/set01.json').readAsStringSync(),
  File('assets/data/set02.json').readAsStringSync(),
]);

Map<String, Object?> evaluateEncounter({
  required CardLibrary library,
  required StoryChapter chapter,
  required StoryBattle battle,
  required Setup setup,
  required AiTier skill,
  required int games,
  required int seedBase,
  bool detailed = true,
}) {
  final outcomes = <Map<String, Object?>>[];
  final turns = <int>[];
  var wins = 0, losses = 0, stalls = 0;
  for (var game = 0; game < games; game++) {
    final seed = seedBase + game * campaignSeedStride;
    final result = playBattleDetailed(
      library: library,
      chapter: chapter,
      battle: battle,
      setup: setup,
      playerSkill: skill,
      seed: seed,
    );
    if (result.playerWon == true) wins++;
    if (result.playerWon == false) losses++;
    if (result.stalled) stalls++;
    turns.add(result.turns);
    if (detailed) {
      outcomes.add({
        'seed': seed,
        'result': result.stalled
            ? 'stall'
            : result.playerWon!
            ? 'win'
            : 'loss',
        'turns': result.turns,
      });
    }
  }
  turns.sort();
  // Wilson 95% interval includes stalls in the no-win denominator.
  final rate = wins / games;
  const z = 1.959963984540054;
  final denominator = 1 + z * z / games;
  final centre = (rate + z * z / (2 * games)) / denominator;
  final radius =
      z *
      sqrt(rate * (1 - rate) / games + z * z / (4 * games * games)) /
      denominator;
  return {
    'skill': skill.name,
    'wins': wins,
    'losses': losses,
    'stalls': stalls,
    'games': games,
    'winRate': rate,
    'wilson95': [centre - radius, centre + radius],
    'turns': {
      'mean': turns.reduce((a, b) => a + b) / games,
      'median': turns[games ~/ 2],
      'p90': turns[(games * .9).ceil() - 1],
      'max': turns.last,
    },
    if (detailed) 'outcomes': outcomes,
  };
}

void main(List<String> args) {
  final flags = auditFlags(args);
  final games = int.parse(flags['games'] ?? '100');
  final seed = int.parse(flags['seed'] ?? '2026102907');
  if (games < 1) throw ArgumentError.value(games, 'games', 'must be positive');
  final library = campaignLibrary();
  final authored = flags.containsKey('authored');
  final chapters = authored ? authoredStoryChapters : storyChapters;
  final filter = flags['chapters']?.split(',');
  final skills = (flags['skills'] ?? 'greedy,tactician')
      .split(',')
      .map((s) => AiTier.values.byName(s))
      .toList();
  final encounters = <Map<String, Object?>>[];
  final clock = Stopwatch()..start();
  for (final chapter in chapters) {
    if (filter != null && !filter.contains(chapter.id)) continue;
    var number = 0;
    for (final (stageIndex, stage) in chapter.stages.indexed) {
      final battle = stage.battle;
      if (battle == null) continue;
      number++;
      final band = storyDifficultyBand(chapter.id, number);
      final result = <String, Object?>{
        'id': '${chapter.id}.$number',
        'chapterId': chapter.id,
        'stageIndex': stageIndex,
        'battleNumber': number,
        'enemyName': battle.enemyName,
        'band': band.name,
        'target': [
          band.lower,
          chapter.id == 'ch1' && number == 1 ? .95 : band.upper,
        ],
        if (chapter.id == 'ch1' && number == 1)
          'targetNote': 'The first true tutorial may reach 95%.',
        'playerDominion': chapter.playerDominion,
        'enemyDominion': battle.enemyDominion,
        'deckSetCode': battle.deckSetCode ?? 'SF001',
        'deckVariant': battle.deckVariant,
        'enemyAi': battle.hardAi ? 'strategist' : 'tactician',
        'playerHealth': battle.playerHealth,
        'enemyHealth': battle.enemyHealth,
        'playerFirst': battle.playerFirst,
        'playerBoardIds': battle.playerBoardIds,
        'enemyBoardIds': battle.enemyBoardIds,
        'playerDeckIds': storyDeck(
          library,
          chapter.playerDominion,
          setCode: battle.deckSetCode,
          variant: battle.deckVariant,
        ).map((c) => c.id).toList(),
        'enemyDeckIds': storyDeck(
          library,
          battle.enemyDominion,
          setCode: battle.deckSetCode,
          variant: battle.deckVariant + 1,
        ).map((c) => c.id).toList(),
        'results': [
          for (final skill in skills)
            evaluateEncounter(
              library: library,
              chapter: chapter,
              battle: battle,
              setup: Setup.of(battle),
              skill: skill,
              games: games,
              seedBase: seed,
            ),
        ],
      };
      encounters.add(result);
      final rates = (result['results'] as List)
          .map(
            (r) => '${r['skill']}: ${(r['winRate'] * 100).toStringAsFixed(1)}%',
          )
          .join(', ');
      stdout.writeln('${result['id']} $rates');
    }
  }
  final output = {
    'schema': 'shardfall.story-difficulty-audit.v1',
    'sourceBaseRevision': 'bbd7b57152b456f7bf7c9f1a3523fb5de069c039',
    'setupSource': authored ? 'authored' : 'fixed-0.2.2',
    'seedBase': seed,
    'seedStride': campaignSeedStride,
    'gamesPerEncounterPerSkill': games,
    'turnUnit': 'one player turn (not a full round)',
    'guard': '300 simulator iterations; unfinished games count as stalls',
    'humanRateCaveat': 'AI policy proxies are not guaranteed human win rates.',
    'encounters': encounters,
  };
  final path = flags['out'];
  if (path != null) {
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  }
  stdout.writeln(
    '${encounters.length} encounters in ${clock.elapsedMilliseconds} ms',
  );
}
