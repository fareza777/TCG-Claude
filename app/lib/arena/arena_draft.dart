import 'dart:math';

import 'package:shardfall_engine/shardfall_engine.dart';

/// Deckbuilding for an arena run: twenty-four choices of one card from three.
///
/// The deck that comes out is a legal 40-card list — the twenty-four cards you
/// picked plus sixteen Wellsprings. The Wellsprings are not drafted because
/// Aether in this game is dominion-typed: a run needs roughly sixteen of them
/// to function at all, and choosing between two identical Wellsprings is a
/// click, not a decision. What the draft does instead is let your picks decide
/// how those sixteen are split.
///
/// A run is locked to one or two dominions for the same reason. Costs are paid
/// in matching Aether, so a five-colour pile would be a deck of uncastable
/// cards. One colour trades a pool about half the size for Aether that never
/// fails; two colours is the reverse.
class ArenaDraft {
  static const picks = 24;
  static const wellspringCount = 16;
  static const offerSize = 3;

  /// Every sixth pick is guaranteed to offer something rare or better, so a
  /// run has reliable high points instead of depending on luck.
  static const goldenPickEvery = 6;

  /// Minimum Wellsprings for a dominion you actually drafted cards in, so a
  /// light splash never leaves those cards stranded in hand.
  static const _minWellsprings = 5;

  final CardLibrary library;
  final List<Dominion> dominions;
  final Random _rng;

  final List<CardDef> picked = [];
  List<CardDef> offer = const [];

  late final List<CardDef> _pool;

  ArenaDraft({
    required this.library,
    required this.dominions,
    Random? rng,
  }) : _rng = rng ?? Random() {
    _pool = [
      for (final def in library.byId.values)
        if (def.type != CardType.wellspring && _isDraftable(def)) def,
    ];
    _deal();
  }

  /// How many single-colour and two-colour options a run is offered.
  static const monoOffers = 2;
  static const pairOffers = 4;

  static const _colours = [
    Dominion.verdance,
    Dominion.pyre,
    Dominion.tide,
    Dominion.dawn,
    Dominion.gloom,
  ];

  /// The colour choices for a run: [monoOffers] single dominions followed by
  /// [pairOffers] pairs, none repeated. Singles come first so the screen can
  /// group them, and because they are the rarer, more particular choice.
  static List<List<Dominion>> rollRuns(Random rng) {
    final mono = [
      for (final d in _colours) [d],
    ]..shuffle(rng);

    final pairs = <List<Dominion>>[
      for (var i = 0; i < _colours.length; i++)
        for (var j = i + 1; j < _colours.length; j++)
          [_colours[i], _colours[j]],
    ]..shuffle(rng);

    return [...mono.take(monoOffers), ...pairs.take(pairOffers)];
  }

  /// A card belongs in this run if every Aether it demands is a colour the run
  /// can actually produce. Generic cost is payable from anything.
  bool _isDraftable(CardDef def) {
    if (def.costDominion.keys.any((d) => !dominions.contains(d))) return false;
    return def.dominions.any(dominions.contains);
  }

  int get pickNumber => picked.length + 1;
  bool get isComplete => picked.length >= picks;

  bool get _isGoldenPick => pickNumber % goldenPickEvery == 0;

  int _weightOf(Rarity r) => switch (r) {
        Rarity.common => 40,
        Rarity.uncommon => 18,
        Rarity.rare => 6,
        Rarity.epic => 2,
        Rarity.legendary => 1,
      };

  CardDef _weightedDraw(List<CardDef> from) {
    var total = 0;
    for (final c in from) {
      total += _weightOf(c.rarity);
    }
    var roll = _rng.nextInt(total);
    for (final c in from) {
      roll -= _weightOf(c.rarity);
      if (roll < 0) return c;
    }
    return from.last;
  }

  void _deal() {
    if (isComplete) {
      offer = const [];
      return;
    }
    final chosen = <CardDef>[];

    if (_isGoldenPick) {
      final premium = [
        for (final c in _pool)
          if (c.rarity.index >= Rarity.rare.index) c,
      ];
      if (premium.isNotEmpty) chosen.add(premium[_rng.nextInt(premium.length)]);
    }

    var guard = 0;
    while (chosen.length < offerSize && guard++ < 200) {
      final c = _weightedDraw(_pool);
      if (chosen.any((x) => x.id == c.id)) continue;
      chosen.add(c);
    }
    chosen.shuffle(_rng);
    offer = chosen;
  }

  void take(CardDef card) {
    if (isComplete) return;
    picked.add(card);
    _deal();
  }

  /// How the sixteen Wellsprings will be split, given what has been picked so
  /// far. Exposed so the draft screen can show the balance while you build.
  Map<Dominion, int> wellspringSplit() {
    final demand = {for (final d in dominions) d: 0};
    for (final card in picked) {
      for (final entry in card.costDominion.entries) {
        if (demand.containsKey(entry.key)) {
          demand[entry.key] = demand[entry.key]! + entry.value;
        }
      }
    }
    final total = demand.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      // Nothing coloured picked yet: split evenly rather than guess.
      final each = wellspringCount ~/ dominions.length;
      final split = {for (final d in dominions) d: each};
      split[dominions.first] =
          split[dominions.first]! + wellspringCount - each * dominions.length;
      return split;
    }

    final split = <Dominion, int>{};
    for (final d in dominions) {
      split[d] = demand[d] == 0
          ? 0
          : max(_minWellsprings,
              (wellspringCount * demand[d]! / total).round());
    }
    // Rounding and the floor can push the total off sixteen; settle the
    // difference against the dominion the deck leans on hardest.
    final lead = dominions.reduce((a, b) => demand[a]! >= demand[b]! ? a : b);
    var sum = split.values.fold(0, (a, b) => a + b);
    split[lead] = split[lead]! + (wellspringCount - sum);
    if (split[lead]! < 0) {
      split[lead] = 0;
      sum = split.values.fold(0, (a, b) => a + b);
      final other = dominions.firstWhere((d) => d != lead, orElse: () => lead);
      split[other] = split[other]! + (wellspringCount - sum);
    }
    return split;
  }

  CardDef _wellspringFor(Dominion d) => library.byId.values.firstWhere(
        (c) => c.type == CardType.wellspring && c.dominions.contains(d),
      );

  /// The finished 40-card list: everything picked, plus the Wellsprings.
  List<CardDef> buildDeck() {
    final deck = <CardDef>[...picked];
    wellspringSplit().forEach((dominion, count) {
      for (var i = 0; i < count; i++) {
        deck.add(_wellspringFor(dominion));
      }
    });
    return deck;
  }
}
