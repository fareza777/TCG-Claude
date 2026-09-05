import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/deckbuilder/decks_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';

/// A player wrote in with three complaints that turned out to be one bug:
/// saved decks could not be seen, could not be reopened, and could not be
/// deleted. DECKS opened a blank builder, and `deleteDeck` existed in the
/// save file with nothing calling it. These tests are those three complaints.
class _NoAds implements AdPlatform {
  @override
  Future<void> initialize() async {}
  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async => null;
  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async => null;
  @override
  Future<AdRewardedHandle?> loadRewarded(String adUnitId) async => null;
}

void main() {
  const verdantCard = CardDef(
    id: 'c',
    name: 'Sylvaris Sproutling',
    dominions: [Dominion.verdance],
    type: CardType.unit,
    might: 1,
    guard: 2,
  );
  const library =
      CardLibrary(byId: {'c': verdantCard}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '2026-08-25',
    });
  });

  Future<SaveService> saveWith(Map<String, List<String>> decks) async {
    final save = await SaveService.load(library);
    for (final entry in decks.entries) {
      await save.saveDeck(entry.key, entry.value);
    }
    return save;
  }

  Future<void> pump(WidgetTester tester, SaveService save) async {
    final ads = AdService(save: save, platform: _NoAds());
    addTearDown(ads.dispose);
    await tester.pumpWidget(MaterialApp(
      home: DecksScreen(library: library, save: save, adService: ads),
    ));
    await tester.pump();
  }

  testWidgets('saved decks are actually listed', (tester) async {
    final save = await saveWith({
      'Thorn Rush': List.filled(40, 'c'),
      'Ember Control': List.filled(41, 'c'),
    });
    await pump(tester, save);

    expect(find.text('Thorn Rush'), findsOneWidget);
    expect(find.text('Ember Control'), findsOneWidget);
  });

  testWidgets('a deck too small to play says so', (tester) async {
    // Otherwise the deck simply never appears in PvP and the player is left
    // guessing why.
    final save = await saveWith({'Half Built': List.filled(12, 'c')});
    await pump(tester, save);

    expect(find.textContaining('needs'), findsOneWidget);
  });

  testWidgets('deleting asks first, and then really deletes', (tester) async {
    final save = await saveWith({'Doomed': List.filled(40, 'c')});
    await pump(tester, save);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Backing out must leave the deck alone.
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(save.decks.containsKey('Doomed'), isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(save.decks.containsKey('Doomed'), isFalse);
    expect(find.text('Doomed'), findsNothing);
  });

  testWidgets('a deck holding a card the set no longer has still opens',
      (tester) async {
    // library.card throws on an unknown id, and decks come from a save file.
    // If that crashed the list, the player could not even reach the deck to
    // delete it -- the one thing they would want to do.
    final save = await saveWith({
      'Stale': [...List.filled(39, 'c'), 'SF001-retired'],
    });
    await pump(tester, save);

    expect(find.text('Stale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty collection explains itself', (tester) async {
    final save = await saveWith({});
    await pump(tester, save);

    expect(find.text('No decks yet'), findsOneWidget);
  });

  group('saving', () {
    test('renaming an edited deck moves it rather than copying it', () async {
      // Without `replacing`, editing "My Deck" and calling it "Aggro" left
      // both behind -- and nothing could delete the orphan.
      final save = await saveWith({'My Deck': List.filled(40, 'c')});

      await save.saveDeck('Aggro', List.filled(40, 'c'),
          replacing: 'My Deck');

      expect(save.decks.keys, ['Aggro']);
    });

    test('saving under the same name is an edit, not a duplicate', () async {
      final save = await saveWith({'My Deck': List.filled(40, 'c')});

      await save.saveDeck('My Deck', List.filled(41, 'c'),
          replacing: 'My Deck');

      expect(save.decks.keys, ['My Deck']);
      expect(save.decks['My Deck'], hasLength(41));
    });

    test('a new deck leaves the others alone', () async {
      final save = await saveWith({'One': List.filled(40, 'c')});

      await save.saveDeck('Two', List.filled(40, 'c'));

      expect(save.decks.keys.toList()..sort(), ['One', 'Two']);
    });

    test('deletes survive a reload', () async {
      final save = await saveWith({'Gone': List.filled(40, 'c')});
      await save.deleteDeck('Gone');

      final reloaded = await SaveService.load(library);
      expect(reloaded.decks.containsKey('Gone'), isFalse);
    });
  });
}
