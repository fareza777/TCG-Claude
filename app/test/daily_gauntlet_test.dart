import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/gauntlet/daily_gauntlet.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// A daily challenge fails differently from everything else in the game.
///
/// A bad Arena draft is one player's bad luck. A bad Gauntlet day is bad for
/// every player at once, nobody can play around it, and by the time anyone
/// reports it the day is over. So the whole year is checked in advance rather
/// than sampled — these tests are the reason a broken day never ships.
void main() {
  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  /// Every day for a year from a fixed start, so the run is reproducible.
  List<GauntletDay> aYear() {
    final start = DateTime(2026, 9, 1);
    return [
      for (var i = 0; i < 365; i++)
        DailyGauntlet.build(
            library, DailyGauntlet.idFor(start.add(Duration(days: i)))),
    ];
  }

  test('a year of days all build without throwing', () {
    expect(aYear(), hasLength(365));
  });

  test('every day deals a legal deck', () {
    for (final day in aYear()) {
      expect(day.deckCount, DailyGauntlet.deckSize,
          reason: '${day.id} deals ${day.deckCount} cards');

      day.deck.forEach((id, copies) {
        final def = library.card(id);
        if (def.type == CardType.wellspring) return;
        expect(copies, lessThanOrEqualTo(def.rarity == Rarity.legendary ? 1 : 3),
            reason: '${day.id}: $copies of ${def.name}');
      });
    }
  });

  test('every deck can pay for itself', () {
    // Aether is Dominion-typed. A deck whose Wellsprings do not match its
    // cards is legal on paper and unplayable in the hand -- and the player
    // gets one attempt to find that out.
    for (final day in aYear()) {
      final wells = <Dominion, int>{};
      final needs = <Dominion, int>{};

      day.deck.forEach((id, copies) {
        final def = library.card(id);
        if (def.type == CardType.wellspring) {
          for (final d in def.dominions) {
            if (d != Dominion.neutral) wells[d] = (wells[d] ?? 0) + copies;
          }
        } else {
          def.costDominion.forEach((d, pips) {
            if (pips > 0) needs[d] = (needs[d] ?? 0) + copies;
          });
        }
      });

      expect(wells.values.fold(0, (a, b) => a + b),
          DailyGauntlet.wellspringCount,
          reason: '${day.id} has the wrong number of Wellsprings');

      for (final colour in needs.keys) {
        expect(wells[colour] ?? 0, greaterThanOrEqualTo(4),
            reason: '${day.id} plays $colour cards but has '
                '${wells[colour] ?? 0} $colour Wellsprings');
      }
    }
  });

  test('no deck strays outside its two Dominions', () {
    for (final day in aYear()) {
      expect(day.dominions, hasLength(2));
      day.deck.forEach((id, _) {
        final def = library.card(id);
        final offColour = def.dominions
            .where((d) => d != Dominion.neutral && !day.dominions.contains(d));
        expect(offColour, isEmpty,
            reason: '${day.id}: ${def.name} is ${offColour.join(", ")} in a '
                '${day.dominions.map((d) => d.name).join("/")} deck');
      });
    }
  });

  test('every day has something to do on turn two', () {
    // The single most common way a handed-out deck loses is having no play
    // before turn four, and the player did not choose the deck.
    for (final day in aYear()) {
      var cheap = 0;
      day.deck.forEach((id, copies) {
        final def = library.card(id);
        if (def.type == CardType.wellspring) return;
        if (def.totalCost <= 2) cheap += copies;
      });
      expect(cheap, greaterThanOrEqualTo(4),
          reason: '${day.id} has only $cheap cards costing 2 or less');
    }
  });

  test('the opponent is never the same colour as the loan deck', () {
    for (final day in aYear()) {
      expect(day.dominions, isNot(contains(day.foeDominion)),
          reason: '${day.id} pits the deck against its own colour');
    }
  });

  test('the fight is hard but not hopeless', () {
    for (final day in aYear()) {
      expect(day.playerHealth, inInclusiveRange(18, 25), reason: day.id);
      expect(day.foeHealth, inInclusiveRange(25, 34), reason: day.id);
      expect(day.foeBoard.length, lessThanOrEqualTo(2), reason: day.id);

      // Behind on Health *and* facing a full board *and* the best AI would be
      // a day nobody wins. At most two of those three.
      final hardships = [
        day.playerHealth <= 18,
        day.foeBoard.length >= 2,
        day.foeTier == AiTier.strategist,
      ].where((x) => x).length;
      expect(hardships, lessThan(3),
          reason: '${day.id} stacks every disadvantage at once');
    }
  });

  test('the same date always builds the same day', () {
    // The whole mode rests on this: if two players get different boards, the
    // shared leaderboard is a lie.
    final a = DailyGauntlet.build(library, '2026-09-14');
    final b = DailyGauntlet.build(library, '2026-09-14');

    expect(a.deck, b.deck);
    expect(a.foeDominion, b.foeDominion);
    expect(a.foeTier, b.foeTier);
    expect(a.playerHealth, b.playerHealth);
    expect(a.foeHealth, b.foeHealth);
    expect([for (final c in a.foeBoard) c.id],
        [for (final c in b.foeBoard) c.id]);
  });

  test('different dates build genuinely different days', () {
    final days = aYear();
    final fingerprints = {
      for (final d in days)
        '${d.dominions}|${d.foeDominion}|${d.foeTier}|'
            '${d.playerHealth}|${d.foeHealth}|${d.deck.length}'
    };
    // Not 365 unique — the space is smaller than that — but a year that
    // collapses into a handful of variants would be a treadmill.
    expect(fingerprints.length, greaterThan(60),
        reason: 'only ${fingerprints.length} distinct days in a year');
  });

  test('the briefing always says something', () {
    for (final day in aYear()) {
      expect(day.shape, isNotEmpty, reason: day.id);
    }
  });
}
