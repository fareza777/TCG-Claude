/// Broader diagnostic, with decks declared before observing matchup results.
/// Usage: dart run bin/expansion_archetypes.dart [matches=20] [seed=27182818]
/// Every cross-faction pair of the four panels is played, including cross-panel.
import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';

const factions = ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM'];
const tempo = [
  [2, 4, 7, 16, 19, 22, 25, 26],
  [2, 4, 7, 8, 12, 14, 19, 26],
  [5, 7, 9, 12, 16, 21, 25, 26],
  [2, 6, 8, 11, 12, 19, 25, 26],
  [3, 4, 6, 8, 10, 17, 25, 26],
];
const value = [
  [4, 9, 13, 19, 23, 25, 26, 32],
  [6, 9, 13, 20, 23, 24, 27, 32],
  [4, 8, 9, 12, 21, 25, 26, 27],
  [4, 8, 13, 20, 22, 25, 26, 29],
  [4, 9, 11, 20, 23, 25, 26, 27],
];
// Nine two-copy designs + two epics + one of each legendary; 18 Wellsprings.
const rare = [
  [4, 9, 19, 23, 25, 26, 34, 35, 36],
  [6, 7, 14, 23, 24, 27, 34, 35, 36],
  [4, 7, 9, 21, 25, 26, 34, 35, 36],
  [4, 6, 8, 20, 25, 26, 34, 35, 36],
  [4, 6, 10, 20, 23, 27, 34, 35, 36],
];

String newId(int f, int n) =>
    'SF002-${(f * 43 + n).toString().padLeft(3, '0')}';

class Deck {
  final int faction;
  final String panel;
  final List<CardDef> cards;
  Deck(this.faction, this.panel, this.cards) {
    if (cards.length != 40) throw StateError('Expected 40 cards');
    final counts = <String, int>{};
    for (final card in cards) {
      counts.update(card.id, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final card in cards) {
      if (card.type == CardType.wellspring) continue;
      if (counts[card.id]! > (card.rarity == Rarity.legendary ? 1 : 3)) {
        throw StateError('Illegal copies: ${card.id}');
      }
    }
  }
  String get name => '${factions[faction]}:$panel';
}

List<Deck> archetypes(CardLibrary lib) => [
      for (var f = 0; f < 5; f++) ...[
        for (final entry in {'tempo': tempo[f], 'value': value[f]}.entries)
          Deck(f, entry.key, [
            for (var n = 0; n < 16; n++) lib.card(newId(f, 1)),
            for (final local in entry.value)
              for (var n = 0; n < 3; n++) lib.card(newId(f, local)),
          ]),
        Deck(f, 'rare', [
          for (var n = 0; n < 18; n++) lib.card(newId(f, 1)),
          for (final local in [...rare[f], 41])
            for (var n = 0; n < 2; n++) lib.card(newId(f, local)),
          lib.card(newId(f, 42)),
          lib.card(newId(f, 43)),
        ]),
        Deck(f, 'mixed', [
          for (var n = 0; n < 16; n++) lib.card(newId(f, 1)),
          // First four original starter designs retain a familiar early curve.
          for (final id in lib.starterDecks[factions[f]]!.cardIds.take(4))
            for (var n = 0; n < 3; n++) lib.card(id),
          for (final local in tempo[f].skip(4))
            for (var n = 0; n < 3; n++) lib.card(newId(f, local)),
        ]),
      ],
    ];

void main(List<String> args) {
  final matches = args.isEmpty ? 20 : int.parse(args[0]);
  final seed = args.length < 2 ? 27182818 : int.parse(args[1]);
  if (matches <= 0 || matches.isOdd)
    throw ArgumentError('Use a positive even match count');
  final oldSource = File('../../data/cards/set01_full.json').readAsStringSync();
  final newSource = File('../../data/cards/set02.json').readAsStringSync();
  final lib = CardLibrary.fromJsonStrings([oldSource, newSource]);
  final decks = archetypes(lib);
  const ai = AiPlayer(tier: AiTier.tactician);
  final wins = List.filled(decks.length, 0),
      games = List.filled(decks.length, 0);
  final entered = [for (final _ in decks) <String, int>{}];
  final pairs = <Map<String, dynamic>>[];
  var stalls = 0, plies = 0, matchCount = 0;
  for (var a = 0; a < decks.length; a++) {
    for (var b = a + 1; b < decks.length; b++) {
      if (decks[a].faction == decks[b].faction) continue;
      var aWins = 0, bWins = 0, pairStalls = 0;
      for (var n = 0; n < matches; n++) {
        final seen = [<int>{}, <int>{}];
        var state = Game.create(
            deckP1: decks[a].cards,
            deckP2: decks[b].cards,
            seed: seed + a * 100000 + b * 1000 + n,
            firstPlayer: n.isEven ? PlayerId.p1 : PlayerId.p2);
        var guard = 0;
        while (state.winner == null && guard < 240) {
          state = ai.playTurn(state, state.activePlayer, defenderAi: ai);
          for (final pid in PlayerId.values) {
            for (final card in state.player(pid).arena) {
              if (card.def.type == CardType.unit &&
                  seen[pid.index].add(card.instanceId)) {
                entered[pid == PlayerId.p1 ? a : b]
                    .update(card.def.id, (v) => v + 1, ifAbsent: () => 1);
              }
            }
          }
          guard++;
          if (state.winner == null) state = Game.nextPhase(state);
        }
        plies += guard;
        matchCount++;
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
        'a': decks[a].name,
        'b': decks[b].name,
        'aWins': aWins,
        'bWins': bWins,
        'stalls': pairStalls
      });
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'matchesPerPairing': matches,
    'seedBase': seed,
    'matchCount': matchCount,
    'ai': 'tactician',
    'maxHalfTurns': 240,
    'deckSelection':
        'Declared before observing results; all cross-faction cross-panel pairings; no matchup filtering.',
    'cardsFingerprint': newSource.hashCode.toUnsigned(32).toRadixString(16),
    'decks': {
      for (final d in decks)
        d.name: {
          for (final c in d.cards)
            c.id: d.cards.where((x) => x.id == c.id).length
        }
    },
    'pairs': pairs,
    'stalls': stalls,
    'meanHalfTurns': plies / matchCount,
    'overall': {
      for (var f = 0; f < 5; f++)
        factions[f]: {
          'wins': [
            for (var i = 0; i < decks.length; i++)
              if (decks[i].faction == f) wins[i]
          ].reduce((a, b) => a + b),
          'games': [
            for (var i = 0; i < decks.length; i++)
              if (decks[i].faction == f) games[i]
          ].reduce((a, b) => a + b),
        }
    },
    'byDeck': {
      for (var i = 0; i < decks.length; i++)
        decks[i].name: {
          'wins': wins[i],
          'games': games[i],
          'winPercent': 100 * wins[i] / games[i],
          'unitArenaObservations': entered[i],
        }
    },
  }));
}
