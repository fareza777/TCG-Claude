/// Quick check that Strategist beats Tactician head-to-head.
/// Usage: dart run bin/ai_ladder.dart [matches] [pathToSetJson]
library;

import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_engine/src/data/library.dart';

void main(List<String> args) {
  final matches = args.isNotEmpty ? int.parse(args[0]) : 200;
  final path = args.length > 1 ? args[1] : '../../data/cards/set01_starters.json';
  final lib = CardLibrary.fromJsonString(File(path).readAsStringSync());
  final decks = lib.starterDecks.keys.toList()..sort();

  const strat = AiPlayer(tier: AiTier.strategist);
  const tact = AiPlayer(tier: AiTier.tactician);
  var stratWins = 0, total = 0;

  for (var m = 0; m < matches; m++) {
    final a = decks[m % decks.length];
    final b = decks[(m + 1) % decks.length];
    final stratFirst = m % 2 == 0;
    var s = Game.create(
      deckP1: lib.buildStarterDeck(stratFirst ? a : b),
      deckP2: lib.buildStarterDeck(stratFirst ? b : a),
      seed: m * 31 + 7,
    );
    final p1 = stratFirst ? strat : tact;
    final p2 = stratFirst ? tact : strat;
    var guard = 0;
    while (s.winner == null && guard < 300) {
      final actor = s.activePlayer == PlayerId.p1 ? p1 : p2;
      final def = s.activePlayer == PlayerId.p1 ? p2 : p1;
      s = actor.playTurn(s, s.activePlayer, defenderAi: def);
      if (s.winner != null) break;
      s = Game.nextPhase(s);
      guard++;
    }
    if (s.winner == null) continue;
    final winnerIsStrat =
        (s.winner == PlayerId.p1) == stratFirst;
    if (winnerIsStrat) stratWins++;
    total++;
  }
  final pct = total == 0 ? 0.0 : 100.0 * stratWins / total;
  stdout.writeln('Strategist vs Tactician: ${pct.toStringAsFixed(1)}% '
      '($stratWins/$total). >50% means Strategist is stronger.');
}
