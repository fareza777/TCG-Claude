import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/card_render/card_widget.dart';
import 'package:shardfall/collection/collection_screen.dart';
import 'package:shardfall/deckbuilder/deck_builder_screen.dart';
import 'package:shardfall/forge/forge_screen.dart';
import 'package:shardfall/data/card_catalog.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'expansion_packs_test.dart' show packLibrary;

class _NoAds implements AdPlatform {
  @override
  Future<void> initialize() async {}
  @override
  Future<AdBannerHandle?> loadBanner(String id) async => null;
  @override
  Future<AdInterstitialHandle?> loadInterstitial(String id) async => null;
  @override
  Future<AdRewardedHandle?> loadRewarded(String id) async => null;
}

void main() {
  testWidgets(
    'set filters isolate actual collection, deckbuilder and Forge cards on 320px',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'gold': 120,
        'lastLoginDate': '2026-10-28',
      });
      final library = packLibrary();
      final save = await SaveService.load(library);
      save.owned.addAll({for (final id in library.byId.keys) id: 1});
      final ads = AdService(save: save, platform: _NoAds());
      addTearDown(ads.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 800));
      for (final screen in [
        CollectionScreen(library: library, save: save, adService: ads),
        DeckBuilderScreen(library: library, save: save, adService: ads),
        ForgeScreen(library: library, save: save, adService: ads),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.drag(find.byType(ListView).first, const Offset(-240, 0));
        await tester.pump();
        final filter = find.widgetWithText(ChoiceChip, 'The Five Vows');
        await tester.ensureVisible(filter);
        await tester.tap(filter);
        await tester.pump();
        final cards = tester.widgetList<CardWidget>(find.byType(CardWidget));
        expect(cards, isNotEmpty, reason: '${screen.runtimeType}');
        expect(
          cards.every((card) => CardSet.fiveVows.contains(card.def.id)),
          isTrue,
          reason: '${screen.runtimeType}',
        );
        expect(find.text('SF002'), findsWidgets);
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at 320px',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
