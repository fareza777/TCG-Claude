import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/arena/arena_draft.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// The arena draft has to produce a deck that can actually be played. Aether in
/// this game is dominion-typed, so a draft that wanders across colours hands
/// the player a pile of cards they can never cast — and they would only find
/// out four turns into a run they paid 150 Gold for.
void main() {
  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  ArenaDraft draftTo(int seed, {List<Dominion>? colours}) {
    final rng = Random(seed);
    final draft = ArenaDraft(
      library: library,
      dominions: colours ?? ArenaDraft.rollPairs(rng).first,
      rng: rng,
    );
    while (!draft.isComplete) {
      draft.take(draft.offer[rng.nextInt(draft.offer.length)]);
    }
    return draft;
  }

  test('a pair roll offers three distinct dominion pairs', () {
    final pairs = ArenaDraft.rollPairs(Random(7));
    expect(pairs, hasLength(3));
    final keys = pairs.map((p) => (p..sort((a, b) => a.index - b.index))
        .map((d) => d.name)
        .join('-'));
    expect(keys.toSet(), hasLength(3), reason: 'pairs must not repeat');
    for (final pair in pairs) {
      expect(pair, hasLength(2));
      expect(pair.first, isNot(pair.last));
    }
  });

  test('every offer holds three distinct cards until the draft ends', () {
    final rng = Random(11);
    final draft = ArenaDraft(
      library: library,
      dominions: [Dominion.verdance, Dominion.gloom],
      rng: rng,
    );
    while (!draft.isComplete) {
      expect(draft.offer, hasLength(ArenaDraft.offerSize));
      expect(draft.offer.map((c) => c.id).toSet(), hasLength(3),
          reason: 'pick ${draft.pickNumber} offered a duplicate');
      draft.take(draft.offer.first);
    }
    expect(draft.offer, isEmpty);
  });

  test('the draft ends after exactly twenty-four picks', () {
    final draft = draftTo(3);
    expect(draft.picked, hasLength(ArenaDraft.picks));
    draft.take(library.byId.values.first);
    expect(draft.picked, hasLength(ArenaDraft.picks),
        reason: 'a completed draft must refuse further picks');
  });

  test('every sixth offer contains a rare or better', () {
    final rng = Random(23);
    final draft = ArenaDraft(
      library: library,
      dominions: [Dominion.pyre, Dominion.dawn],
      rng: rng,
    );
    while (!draft.isComplete) {
      if (draft.pickNumber % ArenaDraft.goldenPickEvery == 0) {
        expect(draft.offer.any((c) => c.rarity.index >= Rarity.rare.index),
            isTrue,
            reason: 'pick ${draft.pickNumber} should be a golden pick');
      }
      draft.take(draft.offer.first);
    }
  });

  test('the finished deck is a legal forty cards with sixteen Wellsprings', () {
    for (var seed = 0; seed < 12; seed++) {
      final deck = draftTo(seed).buildDeck();
      expect(deck, hasLength(40), reason: 'seed $seed deck size');
      final wells =
          deck.where((c) => c.type == CardType.wellspring).toList();
      expect(wells, hasLength(ArenaDraft.wellspringCount),
          reason: 'seed $seed Wellspring count');
    }
  });

  test('no drafted card demands Aether the run cannot produce', () {
    for (var seed = 0; seed < 12; seed++) {
      final draft = draftTo(seed);
      final colours = draft.dominions.toSet();
      for (final card in draft.picked) {
        expect(card.costDominion.keys.every(colours.contains), isTrue,
            reason: 'seed $seed drafted ${card.name}, which costs '
                '${card.costDominion.keys.map((d) => d.name).join("/")} in a '
                '${colours.map((d) => d.name).join("/")} run');
      }
    }
  });

  test('a dominion the deck actually uses always gets Wellsprings', () {
    for (var seed = 0; seed < 12; seed++) {
      final draft = draftTo(seed);
      final split = draft.wellspringSplit();
      for (final dominion in draft.dominions) {
        final demand = draft.picked
            .fold(0, (sum, c) => sum + (c.costDominion[dominion] ?? 0));
        if (demand > 0) {
          expect(split[dominion], greaterThanOrEqualTo(4),
              reason: 'seed $seed drafted $demand ${dominion.name} pips but '
                  'was given ${split[dominion]} Wellsprings');
        }
      }
      expect(split.values.fold(0, (a, b) => a + b), ArenaDraft.wellspringCount);
    }
  });
}
