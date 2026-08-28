import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/arena/arena_screen.dart';
import 'package:shardfall/collection/collection_screen.dart';
import 'package:shardfall/deckbuilder/deck_builder_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Header titles must be readable in full on a narrow phone.
///
/// These headers overflowed, were fixed with an ellipsis, and the fix was
/// worse: "Deck Buil..." and "The Proving Gaunt...". Not overflowing is a
/// weaker claim than being readable, and only the weaker one was tested. This
/// checks the real one — the paragraph is not truncated at any phone width.
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
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'gold': SaveService.startGold,
      'lastLoginDate': '2026-08-25',
    });
  });

  /// The narrowest phone worth supporting, and a couple of common ones.
  const widths = [320.0, 360.0, 400.0, 412.0];

  testWidgets('titles are never truncated, at any phone width', (tester) async {
    final save = await SaveService.load(emptyLibrary);
    final ads = AdService(save: save, platform: _NoAds());
    addTearDown(ads.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cases = <String, Widget>{
      'Deck Builder':
          DeckBuilderScreen(library: emptyLibrary, save: save, adService: ads),
      'The Proving Gauntlet':
          ArenaScreen(library: emptyLibrary, save: save, adService: ads),
      'Collection':
          CollectionScreen(library: emptyLibrary, save: save, adService: ads),
    };

    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 800));

      for (final entry in cases.entries) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(MaterialApp(home: entry.value));
        await tester.pump();

        final finder = find.text(entry.key);
        expect(finder, findsOneWidget,
            reason: '"${entry.key}" missing at ${width}px');

        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '"${entry.key}" is cut off at ${width}px — an ellipsis is '
                'not a fixed header');

        expect(tester.takeException(), isNull,
            reason: '"${entry.key}" overflows at ${width}px');
      }
    }
  });
}
