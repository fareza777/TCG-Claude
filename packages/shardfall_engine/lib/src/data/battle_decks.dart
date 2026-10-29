import 'dart:math';
import '../model/card_def.dart';
import '../model/enums.dart';
import 'library.dart';

/// PvE opponents use the entire released catalog, with the same curve and
/// unit/spell budget for every faction. Original collection starters stay fixed.
abstract final class BattleDecks {
  static List<CardDef> build(CardLibrary library, String faction,
      {int seed = 0}) {
    final rng = Random(seed);
    final pool = library.byId.values
        .where((c) =>
            c.dominions.isNotEmpty &&
            c.dominions.every((d) => d.name.toUpperCase() == faction))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final wells = pool.where((c) => c.type == CardType.wellspring).toList();
    final spells = pool.where((c) => c.type != CardType.wellspring).toList();
    if (wells.isEmpty || spells.isEmpty) {
      throw ArgumentError('No playable catalog for $faction');
    }
    final sets = spells.map((c) => c.id.split('-').first).toSet().toList()
      ..sort();
    final counts = <String, int>{};
    final deck = <CardDef>[
      for (var i = 0; i < 16; i++) wells[i % wells.length]
    ];
    // Four 1-cost, six 2-cost, five 3-cost, four 4-cost, three 5-cost,
    // two finishers. Two guaranteed cheap units; remaining roles are shuffled.
    const curve = [
      1,
      1,
      1,
      1,
      2,
      2,
      2,
      2,
      2,
      2,
      3,
      3,
      3,
      3,
      3,
      4,
      4,
      4,
      4,
      5,
      5,
      5,
      6,
      6
    ];
    final roles = [
      for (var i = 0; i < 14; i++) true,
      for (var i = 0; i < 8; i++) false
    ]..shuffle(rng);
    for (var i = 0; i < curve.length; i++) {
      final unit = i < 2 || roles[i - 2];
      var eligible = spells
          .where((c) =>
              (c.type == CardType.unit) == unit &&
              (counts[c.id] ?? 0) < (c.rarity == Rarity.legendary ? 1 : 3))
          .toList();
      final fromSet = eligible
          .where((c) => c.id.startsWith('${sets[i % sets.length]}-'))
          .toList();
      if (fromSet.isNotEmpty) eligible = fromSet;
      if (eligible.isEmpty)
        throw StateError('Insufficient legal $faction cards');
      final band = curve[i];
      var candidates = eligible
          .where((c) => band == 6 ? c.totalCost >= 6 : c.totalCost == band)
          .toList();
      if (candidates.isEmpty) {
        final distance =
            eligible.map((c) => (c.totalCost - band).abs()).reduce(min);
        candidates = eligible
            .where((c) => (c.totalCost - band).abs() == distance)
            .toList();
      }
      final chosen = candidates[rng.nextInt(candidates.length)];
      counts.update(chosen.id, (n) => n + 1, ifAbsent: () => 1);
      deck.add(chosen);
    }
    return deck;
  }
}
