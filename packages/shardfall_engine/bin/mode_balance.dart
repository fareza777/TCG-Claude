/// Actual mixed PvE deck generator, mirrored first player; no curated rosters.
/// Usage: dart run bin/mode_balance.dart [samples=100] [seed=2026102902]
import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';

const factions = ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM'];

PlayerId? play(List<CardDef> a, List<CardDef> b, int seed, PlayerId first) {
  const ai = AiPlayer(tier: AiTier.tactician);
  var state = Game.create(deckP1: a, deckP2: b, seed: seed, firstPlayer: first);
  for (var i = 0; i < 240 && state.winner == null; i++) {
    state = ai.playTurn(state, state.activePlayer, defenderAi: ai);
    if (state.winner == null) state = Game.nextPhase(state);
  }
  return state.winner;
}

void main(List<String> args) {
  final samples = args.isEmpty ? 100 : int.parse(args[0]);
  final seed = args.length < 2 ? 2026102902 : int.parse(args[1]);
  if (samples <= 0 || samples.isOdd)
    throw ArgumentError('Positive even samples required');
  final combined = CardLibrary.fromJsonStrings([
    File('../../data/cards/set01_full.json').readAsStringSync(),
    File('../../data/cards/set02.json').readAsStringSync(),
  ]);
  final source = args.length < 3 ? 'both' : args[2];
  final lib = source == 'both'
      ? combined
      : CardLibrary(byId: {
          for (final c in combined.byId.values)
            if (c.id.startsWith('$source-')) c.id: c,
        }, starterDecks: combined.starterDecks);
  final wins = List.filled(5, 0), games = List.filled(5, 0);
  var stalls = 0, count = 0;
  final pairs = <Map<String, dynamic>>[];
  for (var a = 0; a < 5; a++) {
    for (var b = a + 1; b < 5; b++) {
      var aw = 0, bw = 0, stuck = 0;
      for (var n = 0; n < samples; n++) {
        final deckA =
            BattleDecks.build(lib, factions[a], seed: seed + n * 101 + a);
        final deckB =
            BattleDecks.build(lib, factions[b], seed: seed + n * 101 + b);
        for (final first in PlayerId.values) {
          final winner =
              play(deckA, deckB, seed + a * 100000 + b * 1000 + n, first);
          count++;
          games[a]++;
          games[b]++;
          if (winner == PlayerId.p1) {
            wins[a]++;
            aw++;
          } else if (winner == PlayerId.p2) {
            wins[b]++;
            bw++;
          } else {
            stalls++;
            stuck++;
          }
        }
      }
      pairs.add({
        'a': factions[a],
        'b': factions[b],
        'aWins': aw,
        'bWins': bw,
        'stalls': stuck
      });
    }
  }
  final starters = <Map<String, dynamic>>[];
  for (var a = 0; a < 5; a++) {
    var wins = 0, games = 0, stalls = 0;
    for (var b = 0; b < 5; b++) {
      for (var n = 0; n < samples; n++) {
        final winner = play(
            combined.buildStarterDeck(factions[a]),
            BattleDecks.build(lib, factions[b], seed: seed + n * 101 + b),
            seed + a * 100000 + b * 1000 + n,
            n.isEven ? PlayerId.p1 : PlayerId.p2);
        games++;
        if (winner == PlayerId.p1) wins++;
        if (winner == null) stalls++;
      }
    }
    starters.add({
      'faction': factions[a],
      'wins': wins,
      'games': games,
      'stalls': stalls,
      'winPercent': 100 * wins / games
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'seed': seed,
    'source': source,
    'samplesPerPair': samples,
    'ai': 'tactician',
    'maxHalfTurns': 240,
    'generated': {
      'games': count,
      'stalls': stalls,
      'pairs': pairs,
      'overall': {
        for (var f = 0; f < 5; f++)
          factions[f]: {
            'wins': wins[f],
            'games': games[f],
            'winPercent': 100 * wins[f] / games[f]
          },
      }
    },
    'originalStarterVersusMixed': starters,
    'method':
        'Actual BattleDecks.build decks; independently generated per seed and faction; all faction pairs, mirrored first player. Fixed original starters also face every faction as a difficulty check.',
  }));
}
