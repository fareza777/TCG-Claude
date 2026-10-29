import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/data/card_catalog.dart';
import 'package:shardfall/packs/pack_generator.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

class _CatalogBundle extends CachingAssetBundle {
  final requested = <String>[];
  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final set = key.endsWith('set01.json') ? 'SF001' : 'SF002';
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'cards': [
              {
                'id': '$set-001',
                'name': set,
                'dominion': ['VERDANCE'],
                'type': 'UNIT',
              },
            ],
            if (set == 'SF001')
              'starterDecks': {
                'VERDANCE': {
                  'wellspring': 'SF001-001',
                  'cards': ['SF001-001'],
                },
              },
          }),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'app boundary loads both assets and preserves original starter ids',
    () async {
      final bundle = _CatalogBundle();
      final library = await CardCatalog.load(bundle: bundle);
      expect(
        bundle.requested,
        containsAll(['assets/data/set01.json', 'assets/data/set02.json']),
      );
      expect(library.byId.keys, containsAll(['SF001-001', 'SF002-001']));
      expect(library.starterDecks['VERDANCE']!.cardIds, ['SF001-001']);
    },
  );
  test(
    'packaged catalog adds 215 definitions and preserves old starter decks',
    () async {
      final original = CardLibrary.fromJsonString(
        File('assets/data/set01.json').readAsStringSync(),
      );
      final combined = await CardCatalog.load();
      expect(combined.byId.length, original.byId.length + 215);
      for (final entry in original.starterDecks.entries) {
        expect(
          combined.buildStarterDeck(entry.key).map((c) => c.id),
          original.buildStarterDeck(entry.key).map((c) => c.id),
        );
      }
      for (final set in CardSet.values) {
        final pack = PackGenerator(combined).generate(set);
        expect(pack.every((c) => set.contains(c.id)), isTrue);
        expect(
          pack.every(
            (c) => c.type != CardType.wellspring && c.rarity != Rarity.epic,
          ),
          isTrue,
        );
      }
    },
  );
}
