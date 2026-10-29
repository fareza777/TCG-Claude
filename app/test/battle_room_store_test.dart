import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shardfall/battle_rooms/battle_room_catalog.dart';
import 'package:shardfall/battle_rooms/battle_room_selection.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

class _FailOnceStore extends InMemorySharedPreferencesStore {
  final String failingKey;
  bool failed = false;
  _FailOnceStore(super.data, this.failingKey) : super.withData();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == failingKey && !failed) {
      failed = true;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  Future<SaveService> profile({int gold = 1800, Object? rooms}) async {
    SharedPreferences.setMockInitialValues({
      'gold': gold,
      'lastLoginDate': DateTime.now().toIso8601String().substring(0, 10),
      if (rooms != null) 'battleRooms': jsonEncode(rooms),
    });
    return SaveService.load(library);
  }

  test(
    'four distinct rooms include the upgraded free default and three 600 Gold cosmetics',
    () {
      expect(BattleRooms.all, hasLength(4));
      expect(BattleRooms.classic.goldCost, 0);
      expect(BattleRooms.premium.map((r) => r.goldCost), [600, 600, 600]);
      expect(BattleRooms.all.map((r) => r.asset).toSet(), hasLength(4));
      for (final room in BattleRooms.all) {
        expect(File(room.asset).existsSync(), isTrue);
      }
    },
  );
  test('old saves receive the free courtyard without spending', () async {
    final save = await profile();
    expect(save.ownedBattleRooms, {'classic'});
    expect(save.equippedBattleRoom, 'classic');
    expect(save.gold, 1800);
    expect(BattleRoomSelection.active.value, BattleRooms.classic);
  });
  test(
    'a purchased room is real local progress even when the remaining Gold matches a fresh profile',
    () async {
      final save = await profile(gold: 720);
      expect(save.hasLocalProgress, isFalse);
      await save.purchaseBattleRoom('moonroot');
      expect(save.gold, SaveService.startGold);
      expect(save.hasLocalProgress, isTrue);
    },
  );
  test(
    'buy and equip persists, then repeated and simultaneous purchases charge only once',
    () async {
      final save = await profile();
      final results = await Future.wait([
        save.purchaseBattleRoom('moonroot'),
        save.purchaseBattleRoom('moonroot'),
      ]);
      expect(
        results.where((r) => r == RoomPurchaseResult.purchased),
        hasLength(1),
      );
      expect(save.gold, 1200);
      expect(save.ownedBattleRooms, {'classic', 'moonroot'});
      expect(save.equippedBattleRoom, 'moonroot');
      expect(
        await save.purchaseBattleRoom('moonroot'),
        RoomPurchaseResult.alreadyOwned,
      );
      final loaded = await SaveService.load(library);
      expect(loaded.gold, 1200);
      expect(loaded.ownedBattleRooms, {'classic', 'moonroot'});
      expect(loaded.equippedBattleRoom, 'moonroot');
      expect(BattleRoomSelection.active.value.id, 'moonroot');
    },
  );
  test(
    'unaffordable, unknown and unowned room actions leave wallet and selection unchanged',
    () async {
      final save = await profile(gold: 599);
      expect(
        await save.purchaseBattleRoom('tideglass'),
        RoomPurchaseResult.insufficientGold,
      );
      expect(
        await save.purchaseBattleRoom('missing'),
        RoomPurchaseResult.invalidRoom,
      );
      expect(await save.equipBattleRoom('tideglass'), isFalse);
      expect(await save.equipBattleRoom('missing'), isFalse);
      expect(save.gold, 599);
      expect(save.ownedBattleRooms, {'classic'});
      expect(save.equippedBattleRoom, 'classic');
    },
  );
  test(
    'equipping an owned room or reverting to the free room is free',
    () async {
      final save = await profile();
      await save.purchaseBattleRoom('emberforge');
      expect(await save.equipBattleRoom('classic'), isTrue);
      expect(save.gold, 1200);
      expect(save.equippedBattleRoom, 'classic');
      expect(await save.equipBattleRoom('emberforge'), isTrue);
      expect(save.gold, 1200);
    },
  );
  test(
    'backup and cloud round trips retain ownership; older saves cannot revoke it',
    () async {
      final save = await profile();
      await save.purchaseBattleRoom('tideglass');
      final snapshot = save.toSnapshot(), code = save.exportCode();
      final fresh = await profile();
      expect(await fresh.importCode(code), isTrue);
      expect(fresh.equippedBattleRoom, 'tideglass');
      final other = await profile();
      await other.applySnapshot(snapshot);
      expect(other.ownedBattleRooms, {'classic', 'tideglass'});
      expect(other.equippedBattleRoom, 'tideglass');
      final old = Map<String, dynamic>.from(snapshot)..remove('battleRooms');
      await other.applySnapshot(old);
      expect(other.ownedBattleRooms, {'classic', 'tideglass'});
      expect(other.equippedBattleRoom, 'tideglass');
      final oldCode =
          'SFSAVE-${base64Url.encode(utf8.encode(jsonEncode(old)))}';
      expect(await other.importCode(oldCode), isTrue);
      expect(other.ownedBattleRooms, {'classic', 'tideglass'});
    },
  );
  test(
    'unknown room IDs and malformed selections cannot unlock cosmetics',
    () async {
      final save = await profile(
        rooms: {
          'owned': ['missing', 42, 'classic'],
          'equipped': 'moonroot',
        },
      );
      expect(save.ownedBattleRooms, {'classic'});
      expect(save.equippedBattleRoom, 'classic');
      await save.applySnapshot({
        'battleRooms': {'owned': 'bad', 'equipped': 17},
      });
      expect(save.ownedBattleRooms, {'classic'});
      expect(save.equippedBattleRoom, 'classic');
    },
  );
  for (final failingKey in ['flutter.battleRooms', 'flutter.gold']) {
    test(
      'failed $failingKey write refunds Gold and does not claim ownership',
      () async {
        final save = await profile(gold: 600);
        final initial = await SharedPreferencesStorePlatform.instance.getAll();
        SharedPreferencesStorePlatform.instance = _FailOnceStore(
          initial,
          failingKey,
        );
        expect(
          await save.purchaseBattleRoom('moonroot'),
          RoomPurchaseResult.storageFailed,
        );
        expect(save.gold, 600);
        expect(save.ownedBattleRooms, {'classic'});
        expect(save.equippedBattleRoom, 'classic');
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final restored = await SaveService.load(library);
        expect(restored.gold, 600);
        expect(restored.ownedBattleRooms, {'classic'});
        expect(BattleRoomSelection.active.value.id, 'classic');
      },
    );
  }
}
