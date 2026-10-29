import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall/data/card_catalog.dart';
import 'package:shardfall/packs/pack_generator.dart';
import 'expansion_packs_test.dart' show packLibrary;

void main() {
  test(
    'expansion pack duplicates preserve limits, price and shard conversion',
    () async {
      SharedPreferences.setMockInitialValues({
        'gold': 500,
        'lastLoginDate': '2026-10-28',
      });
      final library = packLibrary();
      final save = await SaveService.load(library);
      for (final card in library.byId.values.where(
        (c) => CardSet.fiveVows.contains(c.id),
      )) {
        save.owned[card.id] = save.maxCopies(card.rarity);
      }
      final before = Map<String, int>.from(save.owned);
      final gold = save.gold;
      final shards = save.shards;
      final pack = PackGenerator(library).generate(CardSet.fiveVows);
      expect(await save.buyPack(pack), isTrue);
      expect(save.gold, gold - 100);
      expect(save.owned, before);
      expect(
        save.shards,
        shards +
            pack.fold<int>(
              0,
              (sum, card) => sum + SaveService.disenchantValue[card.rarity]!,
            ),
      );
      expect(save.totalPacks, 1);
    },
  );

  late CardLibrary library;
  setUp(() {
    final original = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync(),
    );
    library = CardLibrary(
      byId: {
        ...original.byId,
        for (var i = 1; i <= 215; i++)
          'SF002-$i': CardDef(
            id: 'SF002-$i',
            name: 'Vow $i',
            dominions: const [Dominion.verdance],
            type: CardType.unit,
          ),
      },
      starterDecks: original.starterDecks,
    );
    SharedPreferences.setMockInitialValues({
      'gold': 120,
      'lastLoginDate': '2026-10-28',
    });
  });

  test(
    'expansion ownership cannot substitute for original completion',
    () async {
      final save = await SaveService.load(library);
      save.owned.addAll({
        for (final id in library.byId.keys.where(
          (id) => id.startsWith('SF002-'),
        ))
          id: 1,
      });
      await save.completeChapter('vow01');
      expect(save.hasAchievement('full_set'), isFalse);
      for (final id in library.byId.keys.where(
        (id) => id.startsWith('SF001-'),
      )) {
        save.owned[id] = 1;
      }
      await save.completeChapter('vow02');
      expect(save.hasAchievement('full_set'), isTrue);
    },
  );

  test(
    'vow chapters never substitute for the original five chapters',
    () async {
      final save = await SaveService.load(library);
      for (var i = 1; i <= 20; i++) {
        await save.completeChapter('vow${i.toString().padLeft(2, '0')}');
      }
      expect(save.hasAchievement('saga_done'), isFalse);
      for (var i = 1; i <= 5; i++) {
        await save.completeChapter('ch$i');
      }
      expect(save.hasAchievement('saga_done'), isTrue);
      expect(await save.completeChapter('vow20'), 0);
    },
  );

  test(
    'existing saved ids, decks, chapter progress and entitlements survive',
    () async {
      SharedPreferences.setMockInitialValues({
        'gold': 1234,
        'shards': 76,
        'lastLoginDate': '2026-10-28',
        'owned': jsonEncode({'SF001-002': 3}),
        'decks': jsonEncode({
          'Old deck': ['SF001-002', 'SF001-002'],
        }),
        'chapterStage': jsonEncode({'ch5': 4}),
        'chaptersDone': ['ch1'],
        'removeAds': true,
      });
      final save = await SaveService.load(library);
      expect(save.copiesOf('SF001-002'), 3);
      expect(save.decks['Old deck'], ['SF001-002', 'SF001-002']);
      expect(save.stageOf('ch5'), 4);
      expect(save.chapterDone('ch1'), isTrue);
      expect(save.removeAds, isTrue);
      final restored = await SaveService.load(library);
      expect(restored.toSnapshot()['owned'], save.toSnapshot()['owned']);
    },
  );
}
