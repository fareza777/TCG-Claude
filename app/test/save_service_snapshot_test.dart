import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/purchase_catalog.dart';
import 'package:shardfall/services/save_service.dart';

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  /// Snapshots reach the device as JSON out of a `jsonb` column, never as a
  /// Dart map. Round-tripping keeps these tests honest about the real types.
  Map<String, dynamic> overTheWire(Map<String, dynamic> snapshot) =>
      json.decode(json.encode(snapshot)) as Map<String, dynamic>;

  setUp(() {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '${today.year}-${today.month}-${today.day}',
    });
  });

  test('a fresh profile has nothing a cloud restore could destroy', () async {
    final save = await SaveService.load(emptyLibrary);

    expect(save.hasLocalProgress, isFalse);
  });

  test('a played profile is protected from being overwritten', () async {
    final save = await SaveService.load(emptyLibrary);

    await save.rewardStoryBattle('ch1:1');

    expect(save.hasLocalProgress, isTrue);
  });

  test('a snapshot round-trips the profile', () async {
    final save = await SaveService.load(emptyLibrary);
    await save.addGold(400);
    await save.saveDeck('Verdance', ['SF001-001', 'SF001-002']);
    await save.setColorblind(true);
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-snapshot',
    );
    final snapshot = overTheWire(save.toSnapshot());
    final expectedGold = save.gold;

    // A reinstall: empty storage, then the snapshot comes back down.
    SharedPreferences.setMockInitialValues({});
    final restored = await SaveService.load(emptyLibrary);
    await restored.applySnapshot(snapshot);

    expect(restored.gold, expectedGold);
    expect(restored.decks['Verdance'], ['SF001-001', 'SF001-002']);
    expect(restored.colorblind, isTrue);
    // The delivered purchase is still known, so a restore cannot re-grant it.
    expect(
      await restored.grantPurchasedGold(
        productId: PurchaseCatalog.gold500Id,
        purchaseId: 'token-snapshot',
      ),
      isFalse,
    );
    expect(restored.gold, expectedGold);
  });

  test('applying a snapshot keeps purchases this device already knew',
      () async {
    final save = await SaveService.load(emptyLibrary);
    await save.grantPurchasedGold(
      productId: PurchaseCatalog.gold500Id,
      purchaseId: 'token-local',
    );
    final goldAfterLocalGrant = save.gold;

    // An older snapshot, taken before that purchase happened.
    await save.applySnapshot(
      overTheWire({'gold': goldAfterLocalGrant, 'owned': <String, int>{}}),
    );

    expect(
      await save.grantPurchasedGold(
        productId: PurchaseCatalog.gold500Id,
        purchaseId: 'token-local',
      ),
      isFalse,
    );
    expect(save.gold, goldAfterLocalGrant);
  });
}
