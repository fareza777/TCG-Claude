import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

void main() {
  final oldJson = File('../../data/cards/set01_full.json').readAsStringSync();
  test(
      'non-Wellspring designs do not use faction recolors as mechanical padding',
      () {
    final doc =
        jsonDecode(File('../../data/cards/set02.json').readAsStringSync())
            as Map;
    final signatures = <String, String>{};
    for (final card in (doc['cards'] as List).cast<Map>()) {
      if (card['type'] == 'WELLSPRING') continue;
      final cost = card['cost'] as Map;
      var signature = jsonEncode({
        'type': card['type'],
        'cost': cost.values.toList(),
        'might': card['might'],
        'guard': card['guard'],
        'keywords': card['keywords'],
        'effects': card['effects'],
      });
      for (final faction in ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM']) {
        signature = signature.replaceAll(faction, 'FACTION');
      }
      expect(signatures.containsKey(signature), isFalse,
          reason: '${card['name']} duplicates ${signatures[signature]}');
      signatures[signature] = card['name'] as String;
    }
  });
  test('expansion has 215 specific designs and exact faction rarity budgets',
      () {
    final file = File('../../data/cards/set02.json');
    expect(file.existsSync(), isTrue);
    final doc = jsonDecode(file.readAsStringSync()) as Map;
    final cards = (doc['cards'] as List).cast<Map>();
    expect(cards.length, 215);
    expect(cards.map((c) => c['id']).toSet().length, 215);
    expect(cards.map((c) => c['name']).toSet().length, 215);
    expect(cards.map((c) => c['art_prompt']).toSet().length, 215);
    expect(cards.map((c) => c['art_intent']).toSet().length, 215);
    expect(cards.map((c) => c['art_narrative']).toSet().length, 215);
    expect(
        cards.every((c) =>
            (c['art_narrative'] as String).contains(c['name'] as String)),
        isTrue);
    expect(
        cards
            .where((c) =>
                (c['art_composition'] as String).startsWith('monumental hero'))
            .length,
        3);
    for (var f = 0; f < 5; f++) {
      final faction = ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM'][f];
      final rows = cards
          .where((c) => (c['dominion'] as List).single == faction)
          .toList();
      expect(rows.length, 43);
      expect(rows.where((c) => c['type'] == 'WELLSPRING').length, 1);
      for (final r in {
        'COMMON': 21,
        'UNCOMMON': 12,
        'RARE': 7,
        'EPIC': 1,
        'LEGENDARY': 2
      }.entries) {
        expect(rows.where((c) => c['rarity'] == r.key).length, r.value);
      }
      expect(rows.map((c) => c['id']), [
        for (var i = 1; i <= 43; i++)
          'SF002-${(f * 43 + i).toString().padLeft(3, '0')}'
      ]);
      expect(
          rows.every((c) => (c['art_prompt'] as String)
              .startsWith('epic fantasy trading card game illustration')),
          isTrue);
    }
    expect(File('../../app/assets/data/set02.json').readAsStringSync(),
        file.readAsStringSync());
  });
  test(
      'multiple sets merge while original starter decks remain byte-for-byte equivalent',
      () {
    final old = CardLibrary.fromJsonString(oldJson);
    final merged = CardLibrary.fromJsonStrings(
        [oldJson, File('../../data/cards/set02.json').readAsStringSync()]);
    expect(merged.byId.length, old.byId.length + 215);
    expect(merged.byId.keys.toSet().containsAll(old.byId.keys), isTrue);
    for (final key in old.starterDecks.keys) {
      expect(merged.buildStarterDeck(key).map((c) => c.id),
          old.buildStarterDeck(key).map((c) => c.id));
    }
    expect(() => CardLibrary.fromJsonStrings([oldJson, oldJson]),
        throwsFormatException);
  });
}
