import 'enums.dart';

/// Immutable card definition — loaded from set JSON. One per unique card.
class CardDef {
  final String id;
  final String name;
  final List<Dominion> dominions;
  final CardType type;
  final String subtype;
  final Map<Dominion, int> costDominion;
  final int costGeneric;
  final int? might;
  final int? guard;
  final Set<Keyword> keywords;
  final int aegisValue;
  final Rarity rarity;
  final List<Map<String, dynamic>> effects; // Effect DSL, interpreted by engine
  final String text;
  final String flavor;

  const CardDef({
    required this.id,
    required this.name,
    required this.dominions,
    required this.type,
    this.subtype = '',
    this.costDominion = const {},
    this.costGeneric = 0,
    this.might,
    this.guard,
    this.keywords = const {},
    this.aegisValue = 0,
    this.rarity = Rarity.common,
    this.effects = const [],
    this.text = '',
    this.flavor = '',
  });

  int get totalCost =>
      costGeneric + costDominion.values.fold(0, (a, b) => a + b);

  bool get isPermanent =>
      type == CardType.unit ||
      type == CardType.sigil ||
      type == CardType.relic ||
      type == CardType.wellspring;

  static CardDef fromJson(Map<String, dynamic> json) {
    final costJson = (json['cost'] as Map<String, dynamic>?) ?? const {};
    final costDominion = <Dominion, int>{};
    var generic = 0;
    for (final entry in costJson.entries) {
      if (entry.key == 'generic') {
        generic = entry.value as int;
      } else {
        costDominion[Dominion.values.byName(entry.key.toLowerCase())] =
            entry.value as int;
      }
    }
    final keywords = <Keyword>{};
    var aegis = 0;
    for (final k in (json['keywords'] as List?) ?? const []) {
      final name = (k as String).toLowerCase();
      if (name.startsWith('aegis')) {
        keywords.add(Keyword.aegis);
        aegis = int.parse(name.split('_').last);
      } else {
        keywords.add(Keyword.values.byName(name));
      }
    }
    return CardDef(
      id: json['id'] as String,
      name: json['name'] as String,
      dominions: [
        for (final d in (json['dominion'] as List))
          Dominion.values.byName((d as String).toLowerCase()),
      ],
      type: CardType.values.byName((json['type'] as String).toLowerCase()),
      subtype: (json['subtype'] as String?) ?? '',
      costDominion: costDominion,
      costGeneric: generic,
      might: json['might'] as int?,
      guard: json['guard'] as int?,
      keywords: keywords,
      aegisValue: aegis,
      rarity:
          Rarity.values.byName(((json['rarity'] as String?) ?? 'common').toLowerCase()),
      effects: [
        for (final e in (json['effects'] as List?) ?? const [])
          Map<String, dynamic>.from(e as Map),
      ],
      text: (json['text'] as String?) ?? '',
      flavor: (json['flavor'] as String?) ?? '',
    );
  }
}
