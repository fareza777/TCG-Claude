import 'dart:convert';

import '../model/card_def.dart';

/// Card library loaded from a set JSON document (see data/cards/SCHEMA.md).
class CardLibrary {
  final Map<String, CardDef> byId;
  final Map<String, StarterDeck> starterDecks;

  const CardLibrary({required this.byId, required this.starterDecks});

  static CardLibrary fromJsonString(String jsonString) {
    final doc = json.decode(jsonString) as Map<String, dynamic>;
    final byId = <String, CardDef>{};
    for (final raw in (doc['cards'] as List)) {
      final def = CardDef.fromJson(Map<String, dynamic>.from(raw as Map));
      byId[def.id] = def;
    }
    final starters = <String, StarterDeck>{};
    final startersJson =
        (doc['starterDecks'] as Map<String, dynamic>?) ?? const {};
    for (final entry in startersJson.entries) {
      final spec = Map<String, dynamic>.from(entry.value as Map);
      starters[entry.key] = StarterDeck(
        name: entry.key,
        wellspringId: spec['wellspring'] as String,
        cardIds: [for (final id in (spec['cards'] as List)) id as String],
      );
    }
    return CardLibrary(byId: byId, starterDecks: starters);
  }

  CardDef card(String id) {
    final def = byId[id];
    if (def == null) throw ArgumentError('Unknown card id: $id');
    return def;
  }

  /// Build a 40-card starter deck list: 16 wellsprings + 3 copies of each
  /// of the 8 deck cards.
  List<CardDef> buildStarterDeck(String dominionKey) {
    final spec = starterDecks[dominionKey];
    if (spec == null) throw ArgumentError('Unknown starter: $dominionKey');
    return [
      for (var i = 0; i < 16; i++) card(spec.wellspringId),
      for (final id in spec.cardIds)
        for (var i = 0; i < 3; i++) card(id),
    ];
  }
}

class StarterDeck {
  final String name;
  final String wellspringId;
  final List<String> cardIds;

  const StarterDeck({
    required this.name,
    required this.wellspringId,
    required this.cardIds,
  });
}
