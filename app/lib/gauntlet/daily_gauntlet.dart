import 'dart:math';

import 'package:shardfall_engine/shardfall_engine.dart';

/// One day's challenge.
///
/// Everything here is derived from the date, so every device computes the same
/// challenge without a server sending anything — and, because the engine draws
/// all its randomness from [seed] and the AI has none of its own, two players
/// making the same choices get the same result. That is what makes a shared
/// daily board honest rather than decorative.
class GauntletDay {
  /// `yyyy-mm-dd`, and the identity of the attempt in save data.
  final String id;
  final int seed;

  /// The two Dominions of the loan deck.
  final List<Dominion> dominions;

  /// cardId -> copies, Wellsprings included. Always [deckSize] cards.
  final Map<String, int> deck;

  final Dominion foeDominion;
  final AiTier foeTier;
  final int playerHealth;
  final int foeHealth;

  /// Units already on the opponent's side when the match opens.
  final List<CardDef> foeBoard;

  const GauntletDay({
    required this.id,
    required this.seed,
    required this.dominions,
    required this.deck,
    required this.foeDominion,
    required this.foeTier,
    required this.playerHealth,
    required this.foeHealth,
    required this.foeBoard,
  });

  int get deckCount => deck.values.fold(0, (a, b) => a + b);

  /// A short line for the briefing: what shape today is.
  String get shape {
    if (playerHealth <= 18) return 'You start behind. Survive it.';
    if (foeHealth >= 32) return 'They are a wall. Find the way through.';
    if (foeBoard.length >= 2) return 'They are already on the board.';
    return 'An even fight, decided by how you play it.';
  }
}

/// Builds the day, and nothing else.
///
/// Kept free of Flutter and of save state so the generator can be run for a
/// year of dates in a test. A daily challenge fails differently from other
/// features: a bad day is bad for every player at once, and no one can play
/// around it. So it has to be provable in advance, not reported afterwards.
class DailyGauntlet {
  DailyGauntlet._();

  static const deckSize = 40;
  static const wellspringCount = 16;
  static int get spellCount => deckSize - wellspringCount;

  /// Cards to aim for at each total Aether cost.
  ///
  /// Weighted low for the same reason the deck suggester is: a loan deck that
  /// cannot act before turn four loses to the clock rather than to the
  /// opponent, and the player did not choose it.
  static const _curve = <int, int>{1: 4, 2: 6, 3: 5, 4: 4, 5: 3, 6: 2};

  static String idFor(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}'
      '-${when.day.toString().padLeft(2, '0')}';

  /// The seed for a date. Plain and stable: the date read as a number.
  static int seedFor(String dayId) =>
      int.tryParse(dayId.replaceAll('-', '')) ?? 0;

  static int _maxCopies(CardDef def) =>
      def.rarity == Rarity.legendary ? 1 : 3;

  /// Builds the challenge for [dayId].
  ///
  /// Throws [StateError] if the library cannot furnish a legal deck — better a
  /// loud failure in a test than a silent unplayable day in a player's hands.
  static GauntletDay build(CardLibrary library, String dayId) {
    final seed = seedFor(dayId);
    final rng = Random(seed);
    final all = library.byId.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // stable input order

    final colours = _pickDominions(all, rng);
    final deck = _buildDeck(all, colours, rng);
    _addWellsprings(all, colours, deck);

    final foeDominion = _pickFoe(all, colours, rng);

    var tier = AiTier.values[rng.nextInt(AiTier.values.length)];
    // The player is usually the underdog. That is the mode's character: an
    // even fight every day would make the daily forgettable.
    final playerHealth = const [18, 20, 20, 22, 25][rng.nextInt(5)];
    final foeHealth = const [25, 28, 30, 30, 34][rng.nextInt(5)];
    final foeBoard = _openingBoard(all, foeDominion, rng);

    // Three independent rolls occasionally agree, and when they do the day is
    // lost before it starts: down on Health, facing a full board, against the
    // sharpest AI. One hardship is a challenge and two is a hard day, but all
    // three is a day nobody wins — and everybody gets that same day. The tier
    // gives way because it is the one that can be softened without changing
    // the shape the briefing promises.
    final hardships = [
      playerHealth <= 18,
      foeBoard.length >= 2,
      tier == AiTier.strategist,
    ].where((x) => x).length;
    if (hardships >= 3) tier = AiTier.tactician;

    return GauntletDay(
      id: dayId,
      seed: seed,
      dominions: colours,
      deck: deck,
      foeDominion: foeDominion,
      foeTier: tier,
      playerHealth: playerHealth,
      foeHealth: foeHealth,
      foeBoard: foeBoard,
    );
  }

  /// Two Dominions that both have enough playable cards to fill a curve.
  static List<Dominion> _pickDominions(List<CardDef> all, Random rng) {
    final playable = <Dominion, int>{};
    for (final def in all) {
      if (def.type == CardType.wellspring) continue;
      for (final d in def.dominions) {
        if (d == Dominion.neutral) continue;
        playable[d] = (playable[d] ?? 0) + 1;
      }
    }
    final viable = playable.entries
        .where((e) => e.value >= 8)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (viable.length < 2) {
      throw StateError('fewer than two Dominions can field a deck');
    }

    final first = viable[rng.nextInt(viable.length)];
    final rest = viable.where((d) => d != first).toList();
    final second = rest[rng.nextInt(rest.length)];
    return [first, second]..sort((a, b) => a.index.compareTo(b.index));
  }

  /// The spells and units, filled to the curve then topped up cheapest-first.
  static Map<String, int> _buildDeck(
      List<CardDef> all, List<Dominion> colours, Random rng) {
    bool inPool(CardDef d) =>
        d.type != CardType.wellspring &&
        (d.dominions.any(colours.contains) ||
            d.dominions.every((x) => x == Dominion.neutral));

    final pool = all.where(inPool).toList();
    if (pool.isEmpty) throw StateError('no playable cards for $colours');
    pool.shuffle(rng);

    final deck = <String, int>{};
    var taken = 0;

    int room(CardDef def) {
      final held = deck[def.id] ?? 0;
      final byRarity = _maxCopies(def) - held;
      final byDeck = spellCount - taken;
      return byRarity < byDeck ? byRarity : byDeck;
    }

    void take(CardDef def, int n) {
      if (n <= 0) return;
      deck[def.id] = (deck[def.id] ?? 0) + n;
      taken += n;
    }

    for (final entry in _curve.entries) {
      var want = entry.value;
      for (final def in pool) {
        if (want <= 0 || taken >= spellCount) break;
        if (def.totalCost != entry.key) continue;
        final n = room(def) < want ? room(def) : want;
        take(def, n);
        want -= n;
      }
    }

    // The curve is a preference. A deck four cards short is not a deck.
    if (taken < spellCount) {
      final byCost = [...pool]
        ..sort((a, b) => a.totalCost.compareTo(b.totalCost));
      for (final def in byCost) {
        if (taken >= spellCount) break;
        take(def, room(def));
      }
    }
    if (taken < spellCount) {
      throw StateError('only $taken playable cards available for $colours');
    }
    return deck;
  }

  /// Wellsprings, split by what the deck actually costs.
  ///
  /// Aether is Dominion-typed, so this is not decoration: a deck whose colours
  /// and Wellsprings disagree cannot pay for itself, and the player would find
  /// out four turns into the one attempt they get.
  static void _addWellsprings(
      List<CardDef> all, List<Dominion> colours, Map<String, int> deck) {
    final demand = {for (final d in colours) d: 0};
    deck.forEach((id, count) {
      final def = all.firstWhere((c) => c.id == id);
      if (def.type == CardType.wellspring) return;
      def.costDominion.forEach((d, pips) {
        if (demand.containsKey(d)) demand[d] = demand[d]! + pips * count;
      });
    });

    final total = demand.values.fold(0, (a, b) => a + b);
    final split = <Dominion, int>{};
    if (total == 0) {
      final each = wellspringCount ~/ colours.length;
      for (final d in colours) {
        split[d] = each;
      }
    } else {
      for (final d in colours) {
        split[d] = (wellspringCount * demand[d]! / total).round();
      }
    }
    // Never leave a colour dry, and always land on exactly the count.
    for (final d in colours) {
      if (split[d]! < 4) split[d] = 4;
    }
    var sum = split.values.fold(0, (a, b) => a + b);
    while (sum != wellspringCount) {
      final biggest = split.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final smallest = split.entries.reduce((a, b) => a.value <= b.value ? a : b);
      if (sum > wellspringCount) {
        split[biggest.key] = biggest.value - 1;
        sum -= 1;
      } else {
        split[smallest.key] = smallest.value + 1;
        sum += 1;
      }
    }

    for (final d in colours) {
      final well = all.firstWhere(
        (c) => c.type == CardType.wellspring && c.dominions.contains(d),
        orElse: () => throw StateError('no Wellspring exists for ${d.name}'),
      );
      deck[well.id] = (deck[well.id] ?? 0) + split[d]!;
    }
  }

  static Dominion _pickFoe(
      List<CardDef> all, List<Dominion> colours, Random rng) {
    final others = <Dominion>{
      for (final def in all)
        for (final d in def.dominions)
          if (d != Dominion.neutral && !colours.contains(d)) d,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (others.isEmpty) return colours.first;
    return others[rng.nextInt(others.length)];
  }

  /// Up to two cheap units the opponent starts with.
  static List<CardDef> _openingBoard(
      List<CardDef> all, Dominion dominion, Random rng) {
    final size = const [0, 0, 1, 2][rng.nextInt(4)];
    if (size == 0) return const [];

    final cheap = all
        .where((d) =>
            d.type == CardType.unit &&
            d.dominions.contains(dominion) &&
            d.totalCost <= 3)
        .toList();
    if (cheap.isEmpty) return const [];
    return [for (var i = 0; i < size; i++) cheap[rng.nextInt(cheap.length)]];
  }
}
