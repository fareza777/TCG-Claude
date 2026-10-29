import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

void main() {
  final old = File('../../data/cards/set01_full.json').readAsStringSync();
  final library = CardLibrary.fromJsonStrings([
    old,
    File('../../data/cards/set02.json').readAsStringSync(),
  ]);
  test('mixed opponents are reproducible legal forty-card decks with a curve',
      () {
    for (final faction in ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM']) {
      for (var seed = 0; seed < 50; seed++) {
        final deck = BattleDecks.build(library, faction, seed: seed);
        expect(deck.map((c) => c.id),
            BattleDecks.build(library, faction, seed: seed).map((c) => c.id));
        expect(deck, hasLength(40));
        expect(deck.where((c) => c.type == CardType.wellspring), hasLength(16));
        expect(deck.where((c) => c.type == CardType.unit), hasLength(16));
        final spells =
            deck.where((c) => c.type != CardType.wellspring).toList();
        expect(spells.where((c) => c.id.startsWith('SF002-')), hasLength(12));
        expect(spells.where((c) => c.totalCost <= 2), hasLength(10));
        expect(
            deck.every((c) =>
                c.dominions.every((d) => d.name.toUpperCase() == faction)),
            isTrue);
        for (final c in spells) {
          expect(spells.where((x) => x.id == c.id).length,
              lessThanOrEqualTo(c.rarity == Rarity.legendary ? 1 : 3));
        }
      }
    }
  });
  test('every new non-resource card can actually enter an opponent deck', () {
    final seen = <String>{};
    for (final faction in ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM']) {
      for (var seed = 0; seed < 1000; seed++) {
        seen.addAll(
            BattleDecks.build(library, faction, seed: seed).map((c) => c.id));
      }
    }
    final missing = library.byId.values
        .where((c) => c.id.startsWith('SF002-') && !seen.contains(c.id));
    expect(missing.map((c) => c.id), isEmpty);
  });
  test('single-set library remains supported', () {
    expect(BattleDecks.build(CardLibrary.fromJsonString(old), 'TIDE', seed: 7),
        hasLength(40));
  });
}
