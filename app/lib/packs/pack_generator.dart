import 'dart:math';
import 'package:shardfall_engine/shardfall_engine.dart';
import '../data/card_catalog.dart';
import 'pack_odds.dart';

/// Validate every required rarity before a purchase can spend any Gold.
/// Missing legendary cards are an error, never silently altered odds.
class PackGenerator {
  PackGenerator(this.library, {Random? random}) : _random = random ?? Random();
  final CardLibrary library;
  final Random _random;

  List<CardDef> generate(CardSet set) {
    final pools = <Rarity, List<CardDef>>{};
    for (final rarity in [
      Rarity.common,
      Rarity.uncommon,
      Rarity.rare,
      Rarity.legendary,
    ]) {
      final pool = library.byId.values
          .where(
            (card) =>
                set.contains(card.id) &&
                card.type != CardType.wellspring &&
                card.rarity == rarity,
          )
          .toList();
      if (pool.isEmpty) {
        throw StateError('${set.title} has no ${rarity.name} cards available.');
      }
      pools[rarity] = pool;
    }
    CardDef pick(Rarity rarity) {
      final pool = pools[rarity]!;
      return pool[_random.nextInt(pool.length)];
    }

    // Keep the rare roll first, preserving the established pack algorithm.
    final finalCard = pick(
      _random.nextInt(PackOdds.legendaryOneIn) == 0
          ? Rarity.legendary
          : Rarity.rare,
    );
    return [
      for (var i = 0; i < PackOdds.commonSlots; i++) pick(Rarity.common),
      for (var i = 0; i < PackOdds.uncommonSlots; i++) pick(Rarity.uncommon),
      finalCard,
    ];
  }
}
