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
      // Singles lead a roll, so ask for a pair explicitly: the tests that
      // use the default are about two-colour runs.
      dominions: colours ??
          ArenaDraft.rollRuns(rng).firstWhere((r) => r.length == 2),
      rng: rng,
    );
    while (!draft.isComplete) {
      draft.take(draft.offer[rng.nextInt(draft.offer.length)]);
    }
    return draft;
  }

  String keyOf(List<Dominion> run) =>
      ([...run]..sort((a, b) => a.index - b.index)).map((d) => d.name).join('-');

  test('a roll offers two single colours and four pairs, none repeated', () {
    for (var seed = 0; seed < 20; seed++) {
      final runs = ArenaDraft.rollRuns(Random(seed));
      expect(runs, hasLength(ArenaDraft.monoOffers + ArenaDraft.pairOffers));
      expect(runs.where((r) => r.length == 1),
          hasLength(ArenaDraft.monoOffers));
      expect(runs.where((r) => r.length == 2),
          hasLength(ArenaDraft.pairOffers));
      expect(runs.map(keyOf).toSet(), hasLength(runs.length),
          reason: 'seed $seed offered the same choice twice');
      for (final run in runs.where((r) => r.length == 2)) {
        expect(run.first, isNot(run.last));
      }
    }
  });

  test('every one of the fifteen colour choices can come up', () {
    // The point of offering more is that no combination is unreachable.
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      seen.addAll(ArenaDraft.rollRuns(Random(seed)).map(keyOf));
    }
    expect(seen, hasLength(15),
        reason: 'five single colours and ten pairs, but only '
            '${seen.length} were ever offered');
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

  group('a single-colour run', () {
    const colours = [
      Dominion.verdance,
      Dominion.pyre,
      Dominion.tide,
      Dominion.dawn,
      Dominion.gloom,
    ];

    for (final colour in colours) {
      test('${colour.name} drafts a legal deck it can always cast', () {
        for (var seed = 0; seed < 10; seed++) {
          final draft = draftTo(seed, colours: [colour]);
          expect(draft.picked, hasLength(ArenaDraft.picks));

          final deck = draft.buildDeck();
          expect(deck, hasLength(40), reason: 'seed $seed deck size');

          // Every Wellspring is the one colour -- there is nothing else the
          // deck could be asked to cast.
          final wells =
              deck.where((c) => c.type == CardType.wellspring).toList();
          expect(wells, hasLength(ArenaDraft.wellspringCount));
          expect(wells.every((w) => w.dominions.contains(colour)), isTrue,
              reason: 'seed $seed ${colour.name} run holds a foreign '
                  'Wellspring');

          for (final card in draft.picked) {
            expect(card.costDominion.keys.every((d) => d == colour), isTrue,
                reason: 'seed $seed drafted ${card.name}, which needs '
                    '${card.costDominion.keys.map((d) => d.name).join("/")} '
                    'in a ${colour.name} run');
          }
        }
      });
    }

    test('the Wellsprings are all sixteen of that one colour', () {
      final draft = draftTo(5, colours: [Dominion.tide]);
      expect(draft.wellspringSplit(), {Dominion.tide: 16});
    });

    test('the pool is deep enough that picks are choices, not repeats', () {
      // 24 picks from three cards each. If a colour held only a handful of
      // cards the offers would be the same few over and over.
      for (final colour in colours) {
        final rng = Random(41);
        final draft =
            ArenaDraft(library: library, dominions: [colour], rng: rng);
        final offered = <String>{};
        while (!draft.isComplete) {
          offered.addAll(draft.offer.map((c) => c.id));
          draft.take(draft.offer[rng.nextInt(draft.offer.length)]);
        }
        // Measured over 50 seeds: a single colour offers 24-34 different
        // cards per run (median 29). Twenty leaves room without letting the
        // pool shrink to a handful.
        expect(offered.length, greaterThanOrEqualTo(20),
            reason: '${colour.name} offered only ${offered.length} different '
                'cards across a whole run');
      }
    });

    test('golden picks still find a rare in a single colour', () {
      for (final colour in colours) {
        final draft = ArenaDraft(
            library: library, dominions: [colour], rng: Random(17));
        while (!draft.isComplete) {
          if (draft.pickNumber % ArenaDraft.goldenPickEvery == 0) {
            expect(
                draft.offer.any((c) => c.rarity.index >= Rarity.rare.index),
                isTrue,
                reason: '${colour.name} pick ${draft.pickNumber}');
          }
          draft.take(draft.offer.first);
        }
      }
    });
  });
}
