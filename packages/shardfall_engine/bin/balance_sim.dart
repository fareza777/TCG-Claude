/// Balance simulator: round-robin AI-vs-AI between the 5 starter decks.
///
/// Usage: dart run bin/balance_sim.dart [matchesPerPairing] [pathToSetJson]
library;

import 'dart:io';

import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_engine/src/data/library.dart';

void main(List<String> args) {
  final matches = args.isNotEmpty ? int.parse(args[0]) : 200;
  final path = args.length > 1
      ? args[1]
      : '../../data/cards/set01_starters.json';
  final lib = CardLibrary.fromJsonString(File(path).readAsStringSync());

  final dominions = lib.starterDecks.keys.toList()..sort();
  const ai = AiPlayer(tier: AiTier.tactician);

  // winrate[a][b] = win% of deck a vs deck b (a as P1 half the time).
  final wins = <String, Map<String, int>>{};
  final games = <String, Map<String, int>>{};
  final totalWins = <String, int>{};
  final totalGames = <String, int>{};
  var drawsOrStalls = 0;

  for (var i = 0; i < dominions.length; i++) {
    for (var j = i + 1; j < dominions.length; j++) {
      final a = dominions[i];
      final b = dominions[j];
      for (var m = 0; m < matches; m++) {
        // Alternate who goes first to cancel turn-order bias.
        final aIsP1 = m % 2 == 0;
        final seed = i * 100000 + j * 10000 + m;
        var s = Game.create(
          deckP1: lib.buildStarterDeck(aIsP1 ? a : b),
          deckP2: lib.buildStarterDeck(aIsP1 ? b : a),
          seed: seed,
        );
        var guard = 0;
        while (s.winner == null && guard < 300) {
          s = ai.playTurn(s, s.activePlayer, defenderAi: ai);
          if (s.winner != null) break;
          s = Game.nextPhase(s);
          guard++;
        }
        String? winnerDeck;
        if (s.winner == PlayerId.p1) winnerDeck = aIsP1 ? a : b;
        if (s.winner == PlayerId.p2) winnerDeck = aIsP1 ? b : a;
        if (winnerDeck == null) {
          drawsOrStalls++;
          continue;
        }
        wins.putIfAbsent(a, () => {}).update(b, (v) => winnerDeck == a ? v + 1 : v, ifAbsent: () => winnerDeck == a ? 1 : 0);
        games.putIfAbsent(a, () => {}).update(b, (v) => v + 1, ifAbsent: () => 1);
        totalWins.update(winnerDeck, (v) => v + 1, ifAbsent: () => 1);
        totalGames.update(a, (v) => v + 1, ifAbsent: () => 1);
        totalGames.update(b, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }

  stdout.writeln('=== SHARDFALL balance sim ===');
  stdout.writeln('matches per pairing: $matches, stalls/draws: $drawsOrStalls');
  stdout.writeln('');
  stdout.writeln('pairwise winrate (row vs column):');
  final header = StringBuffer('          ');
  for (final d in dominions) {
    header.write(d.padRight(10));
  }
  stdout.writeln(header);
  for (final a in dominions) {
    final row = StringBuffer(a.padRight(10));
    for (final b in dominions) {
      if (a == b) {
        row.write('-'.padRight(10));
        continue;
      }
      final first = dominions.indexOf(a) < dominions.indexOf(b);
      final w = first ? (wins[a]?[b] ?? 0) : ((games[b]?[a] ?? 0) - (wins[b]?[a] ?? 0));
      final g = first ? (games[a]?[b] ?? 0) : (games[b]?[a] ?? 0);
      final pct = g == 0 ? 0.0 : 100.0 * w / g;
      row.write('${pct.toStringAsFixed(1)}%'.padRight(10));
    }
    stdout.writeln(row);
  }
  stdout.writeln('');
  stdout.writeln('overall winrate:');
  for (final d in dominions) {
    final g = totalGames[d] ?? 0;
    final w = totalWins[d] ?? 0;
    final pct = g == 0 ? 0.0 : 100.0 * w / g;
    final flag = (pct < 45 || pct > 55) ? '  << OUT OF BAND' : '';
    stdout.writeln('  ${d.padRight(10)} ${pct.toStringAsFixed(1)}%  ($w/$g)$flag');
  }
}
