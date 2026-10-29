// Fixed encounter search on reference and validation seeds only. Never uses
// the holdout. HP, seat and at most three allied units are the only candidates.
// Enemy identities, deck lists, AI and engine rules are immutable inputs.
// From app/: dart compile exe tool/story_campaign_calibrate.dart -o build/battle-rooms/story_calibrate.exe
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/story_difficulty.dart';
import 'package:shardfall/story/vow_encounters.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'campaign_difficulty_audit.dart';
import 'story_runner.dart';

const _reference = 2026102907;
const _validation = 2026102908;

class _Candidate {
  final Setup setup;
  final double reference;
  final double validation;
  final double changeCost;
  const _Candidate(
    this.setup,
    this.reference,
    this.validation,
    this.changeCost,
  );
  double get mean => (reference + validation) / 2;
  double score(double goal) =>
      (mean - goal).abs() +
      (reference - validation).abs() * 0.1 +
      changeCost * .0004;
}

String _key(Setup s) =>
    '${s.playerHealth}/${s.enemyHealth}/'
    '${s.playerSecond}/${s.playerBoard.join(',')}';

List<List<String>> _boards(
  CardLibrary library,
  StoryChapter chapter,
  StoryBattle battle,
  int number,
) {
  final base = battle.playerBoardIds;
  // Preserve the authored two/one/one opening help taper. No units are added
  // to the original unaided encounters before the enemy deploys a board.
  if (chapter.id.startsWith('ch') &&
      (number <= 3 || battle.enemyBoardIds.isEmpty)) {
    return [base];
  }
  final deck = storyDeck(
    library,
    chapter.playerDominion,
    setCode: battle.deckSetCode,
    variant: battle.deckVariant,
  );
  final units = deck.where((c) => c.type == CardType.unit).toList()
    ..sort((a, b) => a.totalCost.compareTo(b.totalCost));
  final light = units.first.id;
  final medium = units.firstWhere((c) => c.totalCost >= 2).id;
  final heavy = units.firstWhere((c) => c.totalCost >= 3).id;
  final options = <List<String>>[
    base,
    [],
    [light],
    [medium],
    [heavy],
    [light, light],
    [light, medium],
    [medium, medium],
    [light, heavy],
    [light, light, medium],
    [light, medium, heavy],
  ];
  final seen = <String>{};
  return options.where((b) => seen.add(b.join(','))).toList();
}

double _cost(Setup base, Setup setup) =>
    (base.playerHealth - setup.playerHealth).abs() / 5 +
    (base.enemyHealth - setup.enemyHealth).abs() / 5 +
    (base.playerSecond == setup.playerSecond ? 0 : 2) +
    (base.playerBoard.join(',') == setup.playerBoard.join(',')
        ? 0
        : 2 + (base.playerBoard.length - setup.playerBoard.length).abs());

void main(List<String> args) {
  final flags = auditFlags(args);
  final out = flags['out'] ?? 'build/battle-rooms/campaign-plan.json';
  final only = flags['chapters']?.split(',');
  final library = campaignLibrary();
  final plan = <Map<String, Object?>>[];
  final evidence = <Map<String, Object?>>[];
  final timer = Stopwatch()..start();
  final rateCache = <String, double>{};
  for (final chapter in authoredStoryChapters) {
    if (only != null && !only.contains(chapter.id)) continue;
    var number = 0;
    for (final stage in chapter.stages) {
      final battle = stage.battle;
      if (battle == null) continue;
      number++;
      final base = Setup.of(battle);
      final band = storyDifficultyBand(chapter.id, number);
      // The first fight teaches attacking with two authored deployed units;
      // it can sit at the upper onboarding edge. Later tutorials are still
      // bounded, since they follow the same chapter format rather than reset
      // the player's experience.
      final goal = chapter.id == 'ch1' && number == 1
          ? .90
          : (band.lower + band.upper) / 2;
      final coarse = <String, _Candidate>{};
      double rate(Setup setup, int games, int seed) {
        final key =
            '${chapter.playerDominion}/${battle.enemyDominion}/'
            '${battle.deckSetCode}/${battle.deckVariant}/${battle.hardAi}/'
            '${battle.enemyBoardIds.join(',')}/${_key(setup)}/$games/$seed';
        return rateCache.putIfAbsent(
          key,
          () => winRate(
            library: library,
            chapter: chapter,
            battle: battle,
            setup: setup,
            playerSkill: AiTier.tactician,
            games: games,
            seedBase: seed,
          ),
        );
      }

      _Candidate sample(Setup setup, int games) => _Candidate(
        setup,
        rate(setup, games, _reference),
        rate(setup, games, _validation),
        _cost(base, setup),
      );
      void offer(Setup setup) {
        coarse.putIfAbsent(_key(setup), () => sample(setup, 24));
      }

      // Coarse, symmetric search can both add and remove advantage. Use
      // multiple HP ratios instead of stopping at the first winning setup.
      for (final board in _boards(library, chapter, battle, number)) {
        for (final second in [base.playerSecond, !base.playerSecond]) {
          for (final delta in [-15, -10, -5, 0, 5, 10, 15, 20]) {
            final setup = base.copyWith(
              playerBoard: board,
              playerSecond: second,
              enemyHealth: max(12, min(55, base.enemyHealth + delta)),
            );
            offer(setup);
          }
        }
      }
      final ranked = coarse.values.toList()
        ..sort((a, b) => a.score(goal).compareTo(b.score(goal)));
      final fine = <String, _Candidate>{};
      // Neighbours of the strongest coarse choices are evaluated with 100
      // games on each tuning seed set. Changing player HP as well as foe HP
      // covers setups whose initial board otherwise decides games too early.
      for (final candidate in ranked.take(5)) {
        for (final hpDelta in [-5, 0, 5]) {
          for (final enemyDelta in [-2, 0, 2]) {
            final setup = candidate.setup.copyWith(
              playerHealth: max(20, min(50, base.playerHealth + hpDelta)),
              enemyHealth: max(
                12,
                min(55, candidate.setup.enemyHealth + enemyDelta),
              ),
            );
            fine.putIfAbsent(_key(setup), () => sample(setup, 100));
          }
        }
      }
      final finalists = fine.values.toList()
        ..sort((a, b) => a.score(goal).compareTo(b.score(goal)));
      final chosen = finalists.first;
      plan.add({
        'id': '${chapter.id}.$number',
        'band': band.name,
        'playerHealth': chosen.setup.playerHealth,
        'enemyHealth': chosen.setup.enemyHealth,
        'playerFirst': !chosen.setup.playerSecond,
        'playerBoardIds': chosen.setup.playerBoard,
        'enemyBoardIds': base.enemyBoard,
        'reference': chosen.reference,
        'validation': chosen.validation,
      });
      evidence.add({
        'id': '${chapter.id}.$number',
        'goal': goal,
        'coarseCandidates': coarse.length,
        'finalCandidates': fine.length,
        'top': [
          for (final c in finalists.take(5))
            {
              'setup': _key(c.setup),
              'reference': c.reference,
              'validation': c.validation,
              'changeCost': c.changeCost,
            },
        ],
      });
      stdout.writeln(
        '${chapter.id}.$number ${_key(chosen.setup)} '
        '${chosen.reference.toStringAsFixed(2)}/${chosen.validation.toStringAsFixed(2)} '
        '${coarse.length}+${fine.length} candidates',
      );
      File(out)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'referenceSeed': _reference,
            'validationSeed': _validation,
            'coarseGamesPerSeedSet': 24,
            'finalGamesPerSeedSet': 100,
            'plan': plan,
            'search': evidence,
          }),
        );
    }
  }
  stdout.writeln('finished ${plan.length} encounters in ${timer.elapsed}');
}
