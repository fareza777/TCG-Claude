import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/packs/pack_odds.dart';

void main() {
  test('the disclosed slots account for every card in a pack', () {
    // The final slot is the Rare-or-Legendary one.
    expect(
      PackOdds.commonSlots + PackOdds.uncommonSlots + 1,
      PackOdds.cardsPerPack,
    );
  });

  test('the final slot odds are exhaustive', () {
    expect(PackOdds.rareChance + PackOdds.legendaryChance, closeTo(1.0, 1e-9));
    expect(PackOdds.legendaryChance, greaterThan(0));
  });

  test('odds are shown to two decimals', () {
    expect(PackOdds.percent(PackOdds.legendaryChance), '8.33%');
    expect(PackOdds.percent(PackOdds.rareChance), '91.67%');
  });

  test('Epic is declared unobtainable from packs', () {
    // The generator only ever draws common, uncommon, rare and legendary, so
    // this list is what keeps the disclosure honest about Epic being craft-only.
    expect(PackOdds.unobtainable, contains(Rarity.epic));
  });
}
