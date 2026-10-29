import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/data/card_catalog.dart';
import 'package:shardfall/packs/pack_generator.dart';
import 'package:shardfall/packs/pack_odds.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

CardLibrary packLibrary({Rarity? missing}) => CardLibrary(
  byId: {
    for (final set in CardSet.values)
      for (final rarity in Rarity.values)
        if (rarity != missing)
          '${set.code}-${rarity.name}': CardDef(
            id: '${set.code}-${rarity.name}',
            name: rarity.name,
            dominions: const [Dominion.verdance],
            type: CardType.unit,
            rarity: rarity,
          ),
    for (final set in CardSet.values)
      '${set.code}-spring': CardDef(
        id: '${set.code}-spring',
        name: 'Spring',
        dominions: const [Dominion.verdance],
        type: CardType.wellspring,
      ),
  },
  starterDecks: const {},
);

void main() {
  for (final set in CardSet.values) {
    test(
      '${set.name} actual pulls keep their set and disclosed distribution',
      () {
        final generator = PackGenerator(packLibrary(), random: Random(712));
        var legendary = 0;
        for (var n = 0; n < 12000; n++) {
          final pack = generator.generate(set);
          expect(pack, hasLength(PackOdds.cardsPerPack));
          expect(pack.every((c) => set.contains(c.id)), isTrue);
          expect(
            pack.where(
              (c) => c.type == CardType.wellspring || c.rarity == Rarity.epic,
            ),
            isEmpty,
          );
          expect(pack.take(7).every((c) => c.rarity == Rarity.common), isTrue);
          expect(
            pack.skip(7).take(3).every((c) => c.rarity == Rarity.uncommon),
            isTrue,
          );
          expect([Rarity.rare, Rarity.legendary], contains(pack.last.rarity));
          if (pack.last.rarity == Rarity.legendary) legendary++;
        }
        expect(legendary / 12000, closeTo(PackOdds.legendaryChance, 0.008));
      },
    );
  }

  for (final rarity in [
    Rarity.common,
    Rarity.uncommon,
    Rarity.rare,
    Rarity.legendary,
  ]) {
    test('missing ${rarity.name} pool fails before buying', () {
      final generator = PackGenerator(packLibrary(missing: rarity));
      expect(() => generator.generate(CardSet.fiveVows), throwsStateError);
    });
  }
  test('an empty selected set cannot borrow original cards', () {
    final lib = packLibrary();
    final originalOnly = CardLibrary(
      byId: Map.fromEntries(
        lib.byId.entries.where((e) => CardSet.sundering.contains(e.key)),
      ),
      starterDecks: const {},
    );
    expect(
      () => PackGenerator(originalOnly).generate(CardSet.fiveVows),
      throwsStateError,
    );
  });
}
