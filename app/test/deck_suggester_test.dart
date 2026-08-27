import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/deckbuilder/deck_suggester.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// The suggester's only real duty is to never hand back a deck the game would
/// refuse. A beginner cannot debug "deck is not legal" — if this is wrong, the
/// one button meant to remove the wall becomes the wall.
CardDef unit(
  String id, {
  required int cost,
  required Dominion dominion,
  Rarity rarity = Rarity.common,
  int might = 2,
  int guard = 2,
}) =>
    CardDef(
      id: id,
      name: id,
      dominions: [dominion],
      type: CardType.unit,
      costGeneric: cost,
      might: might,
      guard: guard,
      rarity: rarity,
    );

CardDef wellspring(String id, Dominion dominion) => CardDef(
      id: id,
      name: '$id Wellspring',
      dominions: [dominion],
      type: CardType.wellspring,
    );

/// A library with enough Verdance to build from and a thin Pyre presence.
CardLibrary library({List<CardDef> extra = const []}) {
  final cards = <CardDef>[
    wellspring('ws-verdance', Dominion.verdance),
    wellspring('ws-pyre', Dominion.pyre),
    for (var cost = 1; cost <= 6; cost++)
      for (var i = 0; i < 3; i++)
        unit('v$cost-$i', cost: cost, dominion: Dominion.verdance),
    unit('p1', cost: 1, dominion: Dominion.pyre),
    ...extra,
  ];
  return CardLibrary(
    byId: {for (final c in cards) c.id: c},
    starterDecks: const {},
  );
}

/// Owns three of everything except where overridden.
int Function(String) owning({Map<String, int> only = const {}, int all = 3}) =>
    (id) => only.isEmpty ? all : (only[id] ?? 0);

void main() {
  test('builds a full, legal deck from an ordinary collection', () {
    final result = suggestDeck(library: library(), copiesOwned: owning());

    expect(result.ok, isTrue, reason: result.problem);
    expect(result.size, 40);
    expect(result.dominion, Dominion.verdance,
        reason: 'Verdance is where this collection actually is');
  });

  test('the deck can pay for itself', () {
    // Aether is Dominion-typed. Wellsprings of the wrong colour make a deck
    // that is legal on paper and unplayable in practice.
    final lib = library();
    final result = suggestDeck(library: lib, copiesOwned: owning());

    final wellsprings = {
      for (final e in result.cards.entries)
        if (lib.card(e.key).type == CardType.wellspring) e.key: e.value,
    };
    expect(wellsprings.values.fold(0, (a, b) => a + b), 16);
    for (final id in wellsprings.keys) {
      expect(lib.card(id).dominions, contains(Dominion.verdance));
    }
  });

  test('never suggests more copies than the player owns', () {
    final lib = library();
    // One copy of each Verdance card, so any deck that overreaches shows here.
    final owned = {
      for (final c in lib.byId.values)
        if (c.type != CardType.wellspring) c.id: 1,
    };
    final result = suggestDeck(
      library: lib,
      copiesOwned: (id) => owned[id] ?? 0,
      // Only 19 non-Wellspring cards exist in this library, so ask for a deck
      // that fits inside what is genuinely ownable.
      size: 30,
      wellspringCount: 16,
    );

    expect(result.ok, isTrue, reason: result.problem);
    for (final entry in result.cards.entries) {
      if (lib.card(entry.key).type == CardType.wellspring) continue;
      expect(entry.value, lessThanOrEqualTo(1),
          reason: '${entry.key} was suggested ${entry.value} times but the '
              'player owns 1');
    }
  });

  test('respects the one-copy limit on legendaries', () {
    final lib = library(extra: [
      unit('legend', cost: 2, dominion: Dominion.verdance,
          rarity: Rarity.legendary, might: 9, guard: 9),
    ]);
    final result = suggestDeck(library: lib, copiesOwned: owning());

    expect(result.cards['legend'] ?? 0, lessThanOrEqualTo(1),
        reason: 'a 9/9 is exactly the card a greedy builder would over-take');
  });

  test('says so instead of building an illegal deck', () {
    // Owning almost nothing must produce an explanation, not a short deck.
    final result = suggestDeck(
      library: library(),
      copiesOwned: owning(only: const {'v1-0': 2}),
    );

    expect(result.ok, isFalse);
    expect(result.cards, isEmpty);
    expect(result.problem, isNotNull);
  });

  test('an empty collection is refused politely', () {
    final result = suggestDeck(library: library(), copiesOwned: (_) => 0);

    expect(result.ok, isFalse);
    expect(result.problem, isNotNull);
  });

  group('on the real card set', () {
    // The case the feature exists for: a real player, on the shipping cards,
    // owning nothing but the starter deck the game hands out at first launch.
    // If it fails here it fails for everybody on day one, so the synthetic
    // libraries above are not enough on their own.
    final real = CardLibrary.fromJsonString(
        File('assets/data/set01.json').readAsStringSync());

    Map<String, int> starterCollection(String dominionKey) {
      final owned = <String, int>{};
      for (final card in real.buildStarterDeck(dominionKey)) {
        owned[card.id] = (owned[card.id] ?? 0) + 1;
      }
      return owned;
    }

    for (final key in const ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM']) {
      test('a fresh $key player gets a legal 40-card deck', () {
        final owned = starterCollection(key);
        final result = suggestDeck(
          library: real,
          copiesOwned: (id) => owned[id] ?? 0,
        );

        expect(result.ok, isTrue, reason: result.problem);
        expect(result.size, 40);

        result.cards.forEach((id, count) {
          final def = real.card(id);
          if (def.type == CardType.wellspring) return;
          expect(count, lessThanOrEqualTo(owned[id] ?? 0),
              reason: '$id: suggested $count, owns ${owned[id] ?? 0}');
          expect(count,
              lessThanOrEqualTo(def.rarity == Rarity.legendary ? 1 : 3),
              reason: '$id exceeds its copy limit');
        });
      });
    }
  });

  test('leans on the cheap end of the curve', () {
    final lib = library();
    final result = suggestDeck(library: lib, copiesOwned: owning());

    var cheap = 0;
    var dear = 0;
    result.cards.forEach((id, count) {
      final def = lib.card(id);
      if (def.type == CardType.wellspring) return;
      if (def.totalCost <= 3) cheap += count;
      if (def.totalCost >= 5) dear += count;
    });
    expect(cheap, greaterThan(dear),
        reason: 'having nothing to do on turn two is how beginners lose');
  });
}
