import 'package:shardfall_engine/shardfall_engine.dart';
import '../services/save_service.dart';
import 'deck_rules.dart';

/// Collection decks follow the existing deck-builder rules in either campaign.
/// Wellsprings remain unlimited basics, with the established total cap of 20.
Map<String, List<CardDef>> playableOwnedDecks(
  CardLibrary library,
  SaveService save,
) {
  final result = <String, List<CardDef>>{};
  for (final entry in save.decks.entries) {
    final ids = entry.value;
    if (entry.key.isEmpty ||
        ids.length < DeckRules.minimum ||
        ids.length > DeckRules.maximum ||
        ids.any((id) => !library.byId.containsKey(id))) {
      continue;
    }
    final deck = ids.map(library.card).toList();
    if (deck.where((c) => c.type == CardType.wellspring).length >
        DeckRules.maximumWellsprings) {
      continue;
    }
    final colors = deck
        .expand((c) => c.dominions)
        .where((d) => d != Dominion.neutral)
        .toSet();
    if (colors.length > 2) continue;
    final counts = <String, int>{};
    var legal = true;
    for (final c in deck) {
      final count = counts.update(c.id, (n) => n + 1, ifAbsent: () => 1);
      if (c.type != CardType.wellspring &&
          (count > save.copiesOf(c.id) || count > DeckRules.maximumCopies(c))) {
        legal = false;
        break;
      }
    }
    if (legal) result[entry.key] = List.unmodifiable(deck);
  }
  return result;
}
