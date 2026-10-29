/// Diagnostic counterfactual only: suppress one Neris Vow in memory.
/// This never changes the authored/packaged catalog and is not a legal deck
/// balance result. Paired seeds isolate whether that Vow explains Tide's panel.
import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'expansion_archetypes.dart' as panel;

void main(List<String> args) {
  final matches = args.isEmpty ? 40 : int.parse(args[0]);
  final seed = args.length < 2 ? 57721566 : int.parse(args[1]);
  final old = File('../../data/cards/set01_full.json').readAsStringSync();
  var source = File('../../data/cards/set02.json').readAsStringSync();
  // Reproduce the recorded attribution experiment without rewriting either
  // catalog. Only the seven documented final numeric changes are reversed.
  final preTuning = args.contains('--pre-tuning');
  if (preTuning) {
    final prior = jsonDecode(source) as Map<String, dynamic>;
    final cards = {
      for (final c in (prior['cards'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: c,
    };
    cards['SF002-047']!['guard'] = 1;
    cards['SF002-049']!['might'] = 2;
    cards['SF002-051']!['might'] = 2;
    cards['SF002-055']!['guard'] = 3;
    (cards['SF002-128']!['cost'] as Map)['generic'] = 4;
    cards['SF002-180']!['guard'] = 2;
    cards['SF002-197']!['guard'] = 3;
    source = jsonEncode(prior);
  }
  final baseline = CardLibrary.fromJsonStrings([old, source]);
  final doc = jsonDecode(source) as Map<String, dynamic>;
  final neris = (doc['cards'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((c) => c['id'] == 'SF002-128');
  (neris['effects'] as List).removeWhere((b) => b['trigger'] == 'ON_VOW');
  final counterfactual = CardLibrary.fromJsonStrings([old, jsonEncode(doc)]);
  const ai = AiPlayer(tier: AiTier.tactician);
  final rows = <Map<String, dynamic>>[];
  for (final entry
      in {'baseline': baseline, 'withoutNerisVow': counterfactual}.entries) {
    final decks = panel.archetypes(entry.value);
    final tide = decks.singleWhere((d) => d.name == 'TIDE:rare');
    for (var b = 0; b < decks.length; b++) {
      if (decks[b].faction == 2) continue;
      var wins = 0, stalls = 0;
      for (var n = 0; n < matches; n++) {
        var s = Game.create(
            deckP1: tide.cards,
            deckP2: decks[b].cards,
            seed: seed + b * 1000 + n,
            firstPlayer: n.isEven ? PlayerId.p1 : PlayerId.p2);
        var guard = 0;
        while (s.winner == null && guard++ < 240) {
          s = ai.playTurn(s, s.activePlayer, defenderAi: ai);
          if (s.winner == null) s = Game.nextPhase(s);
        }
        if (s.winner == PlayerId.p1) wins++;
        if (s.winner == null) stalls++;
      }
      rows.add({
        'variant': entry.key,
        'opponent': decks[b].name,
        'wins': wins,
        'games': matches,
        'stalls': stalls
      });
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'purpose': 'Counterfactual attribution, not playable catalog results',
    'matchesPerOpponent': matches,
    'seedBase': seed,
    'catalogConfiguration': preTuning ? 'pre-seven-numeric-tuning' : 'current',
    'change':
        'Remove only ON_VOW from SF002-128 in memory; same card slots, stats, cost, keywords and paired shuffle seeds.',
    'results': rows,
  }));
}
