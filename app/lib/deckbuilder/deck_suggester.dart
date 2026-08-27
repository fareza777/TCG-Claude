import 'package:shardfall_engine/shardfall_engine.dart';

/// Builds a legal, playable deck out of the cards a player already owns.
///
/// A new player opens the deck builder, sees a hundred and ninety-two cards
/// and a minimum of forty, and closes it again. This exists so the answer to
/// "I don't know where to start" is one button rather than a wiki.
///
/// It does not try to be clever. A focused two-cost-heavy curve in a single
/// Dominion beats anything a beginner would assemble by hand, and beating that
/// is the whole job — this is a floor, not a ceiling.
class DeckSuggestion {
  /// cardId -> copies. Empty when no legal deck could be built.
  final Map<String, int> cards;

  /// The Dominion the deck was built around, for the message shown after.
  final Dominion? dominion;

  /// Why it failed, or null on success.
  final String? problem;

  const DeckSuggestion(this.cards, {this.dominion, this.problem});

  bool get ok => problem == null && cards.isNotEmpty;

  int get size => cards.values.fold(0, (a, b) => a + b);
}

/// How many spells and units to aim for at each total Aether cost.
///
/// Weighted low on purpose. The most common way a beginner's deck loses is
/// having nothing to do on turns two and three, which no amount of expensive
/// cards later can undo.
const _curveTargets = <int, int>{
  1: 4,
  2: 6,
  3: 5,
  4: 4,
  5: 3,
  6: 2,
};

/// Copies of one card a deck may hold. Mirrors the deck builder's own rule.
int _maxCopies(CardDef def, int wellspringCap) {
  if (def.type == CardType.wellspring) return wellspringCap;
  return def.rarity == Rarity.legendary ? 1 : 3;
}

/// Builds a deck of [size] cards, [wellspringCount] of them Wellsprings.
///
/// [copiesOwned] is asked for every card, so ownership stays the caller's
/// business and this function stays testable without a save file.
DeckSuggestion suggestDeck({
  required CardLibrary library,
  required int Function(String cardId) copiesOwned,
  int size = 40,
  int wellspringCount = 16,
  int wellspringCap = 20,
}) {
  final all = library.byId.values.toList();

  // ── 1. Pick the Dominion the player is actually equipped to play ────────
  //
  // Counted as copies owned, not distinct cards: three copies of one good
  // two-drop build a deck, three different one-ofs do not.
  final strength = <Dominion, int>{};
  for (final def in all) {
    if (def.type == CardType.wellspring) continue;
    final owned = copiesOwned(def.id);
    if (owned <= 0) continue;
    for (final d in def.dominions) {
      if (d == Dominion.neutral) continue;
      strength[d] = (strength[d] ?? 0) + owned;
    }
  }
  if (strength.isEmpty) {
    return const DeckSuggestion({},
        problem: 'You do not own any cards to build with yet.');
  }
  final dominion =
      strength.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  // ── 2. The pool: that Dominion plus neutrals, minus Wellsprings ─────────
  bool inPool(CardDef def) =>
      def.type != CardType.wellspring &&
      (def.dominions.contains(dominion) ||
          def.dominions.every((d) => d == Dominion.neutral));

  final pool = [
    for (final def in all)
      if (inPool(def) && copiesOwned(def.id) > 0) def,
  ];

  // Strongest first within a cost, so filling a curve slot takes the best
  // card available for it rather than whichever happened to be indexed first.
  int power(CardDef d) => (d.might ?? 0) + (d.guard ?? 0) + d.effects.length * 2;
  pool.sort((a, b) => power(b).compareTo(power(a)));

  final deck = <String, int>{};
  final spellSlots = size - wellspringCount;
  var taken = 0;

  void take(CardDef def, int count) {
    if (count <= 0) return;
    deck[def.id] = (deck[def.id] ?? 0) + count;
    taken += count;
  }

  /// Copies of [def] still legal to add.
  int room(CardDef def) {
    final held = deck[def.id] ?? 0;
    final byRarity = _maxCopies(def, wellspringCap) - held;
    final byOwnership = copiesOwned(def.id) - held;
    final byDeck = spellSlots - taken;
    return [byRarity, byOwnership, byDeck]
        .reduce((a, b) => a < b ? a : b)
        .clamp(0, spellSlots);
  }

  // ── 3. Fill the curve ───────────────────────────────────────────────────
  for (final entry in _curveTargets.entries) {
    var want = entry.value;
    for (final def in pool) {
      if (want <= 0 || taken >= spellSlots) break;
      if (def.totalCost != entry.key) continue;
      final n = room(def) < want ? room(def) : want;
      take(def, n);
      want -= n;
    }
  }

  // ── 4. Top up with anything legal, cheapest first ───────────────────────
  //
  // The curve is a preference, not a constraint. A deck that is four cards
  // short because no five-drop was owned is not a deck.
  if (taken < spellSlots) {
    final byCost = [...pool]..sort((a, b) => a.totalCost.compareTo(b.totalCost));
    for (final def in byCost) {
      if (taken >= spellSlots) break;
      take(def, room(def));
    }
  }

  if (taken < spellSlots) {
    return DeckSuggestion(const {},
        dominion: dominion,
        problem: 'You need $spellSlots playable cards to fill a deck and own '
            '$taken. Open a pack or two first.');
  }

  // ── 5. Wellsprings ──────────────────────────────────────────────────────
  //
  // Aether is Dominion-typed, so these must match the deck or the deck cannot
  // pay for itself. Owning them is not required — Wellsprings are unlimited.
  final wellspring = all.where((c) =>
      c.type == CardType.wellspring && c.dominions.contains(dominion));
  if (wellspring.isEmpty) {
    return DeckSuggestion(const {},
        dominion: dominion,
        problem: 'No Wellspring exists for ${dominion.name}.');
  }
  deck[wellspring.first.id] = wellspringCount;

  return DeckSuggestion(deck, dominion: dominion);
}
