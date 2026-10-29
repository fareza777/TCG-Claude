/// Seeded round robin with exclusively SF002 decks. No old cards are tuned.
/// Usage: dart run bin/expansion_balance.dart [matchesPerPairing=100] [seedBase=20261028]
import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';

const names = ['Verdance', 'Pyre', 'Tide', 'Dawn', 'Gloom'];
const deckLocalIds = [
  [4, 7, 8, 10, 12, 15, 19, 24],
  [6, 7, 8, 10, 12, 15, 19, 24],
  [4, 6, 8, 10, 12, 15, 19, 24],
  [4, 6, 8, 10, 12, 15, 19, 24],
  [4, 6, 8, 10, 12, 15, 19, 24],
];
String id(int i) => 'SF002-${i.toString().padLeft(3, '0')}';
List<CardDef> expansionDeck(CardLibrary lib, int faction) => [
      for (var n = 0; n < 16; n++) lib.card(id(faction * 43 + 1)),
      for (final local in deckLocalIds[faction])
        for (var n = 0; n < 3; n++) lib.card(id(faction * 43 + local)),
    ];
void main(List<String> args) {
  final matches = args.isEmpty ? 100 : int.parse(args[0]);
  final seedBase = args.length < 2 ? 20261028 : int.parse(args[1]);
  final lib = CardLibrary.fromJsonString(
      File('../../data/cards/set02.json').readAsStringSync());
  const ai = AiPlayer(tier: AiTier.tactician);
  final wins = List.filled(5, 0), games = List.filled(5, 0);
  final pairs = <Map<String, dynamic>>[];
  var stalls = 0, plies = 0;
  for (var a = 0; a < 5; a++) {
    for (var b = a + 1; b < 5; b++) {
      var aWins = 0, bWins = 0, pairStalls = 0;
      for (var n = 0; n < matches; n++) {
        final first = n.isEven ? PlayerId.p1 : PlayerId.p2;
        var state = Game.create(
            deckP1: expansionDeck(lib, a),
            deckP2: expansionDeck(lib, b),
            seed: seedBase + a * 100000 + b * 10000 + n,
            firstPlayer: first);
        var guard = 0;
        while (state.winner == null && guard < 240) {
          state = ai.playTurn(state, state.activePlayer, defenderAi: ai);
          guard++;
          if (state.winner == null) state = Game.nextPhase(state);
        }
        plies += guard;
        games[a]++;
        games[b]++;
        if (state.winner == PlayerId.p1) {
          wins[a]++;
          aWins++;
        } else if (state.winner == PlayerId.p2) {
          wins[b]++;
          bWins++;
        } else {
          stalls++;
          pairStalls++;
        }
      }
      pairs.add({
        'a': names[a],
        'b': names[b],
        'aWins': aWins,
        'bWins': bWins,
        'stalls': pairStalls
      });
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'matchesPerPairing': matches,
    'seedBase': seedBase,
    'ai': 'tactician',
    'maxHalfTurns': 240,
    'decks': {
      for (var f = 0; f < 5; f++)
        names[f]: {
          'wellspring': id(f * 43 + 1),
          'cards': deckLocalIds[f].map((n) => id(f * 43 + n)).toList(),
          'copies': 3,
          'wellsprings': 16
        }
    },
    'pairs': pairs,
    'stalls': stalls,
    'meanHalfTurns': plies / (matches * 10),
    'overall': {
      for (var f = 0; f < 5; f++)
        names[f]: {
          'wins': wins[f],
          'games': games[f],
          'winPercent': 100 * wins[f] / games[f]
        }
    },
  }));
}
