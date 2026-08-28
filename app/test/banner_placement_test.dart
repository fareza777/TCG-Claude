import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/arena/arena_screen.dart';
import 'package:shardfall/collection/collection_screen.dart';
import 'package:shardfall/deckbuilder/deck_builder_screen.dart';
import 'package:shardfall/forge/forge_screen.dart';
import 'package:shardfall/progress/achievements_screen.dart';
import 'package:shardfall/quests/quests_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/story/story_screen.dart';
import 'package:shardfall/widgets/ad_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banners were removed from these screens once, then asked back. This file
/// replaces the test that asserted their absence.
///
/// The absence was never the point. What matters is the regression that came
/// with them the first time: a Container with an alignment and no height
/// expands to fill whatever it is offered, and Scaffold.bottomNavigationBar
/// offers the whole screen — which pushed the body to zero and left six
/// screens showing nothing but a banner floating in the dark. So this checks
/// placement *and* that the screen survives it.
class _FakeBannerHandle implements AdBannerHandle {
  @override
  final int width = 320;
  @override
  final int height = 50;

  @override
  Widget buildWidget() => const ColoredBox(color: Color(0xFF223344));

  @override
  void dispose() {}
}

/// Serves a banner, so the widget renders its real layout rather than the
/// empty box it falls back to. A no-op platform would make this test pass
/// while proving nothing.
class _BannerPlatform implements AdPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async =>
      _FakeBannerHandle();

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

  Future<({SaveService save, AdService ads})> services() async {
    final save = await SaveService.load(emptyLibrary);
    return (save: save, ads: AdService(save: save, platform: _BannerPlatform()));
  }

  List<Widget> browsingScreens(SaveService save, AdService ads) => [
        QuestsScreen(save: save, adService: ads),
        AchievementsScreen(save: save, adService: ads),
        CollectionScreen(
            library: emptyLibrary, save: save, adService: ads),
        ForgeScreen(library: emptyLibrary, save: save, adService: ads),
        DeckBuilderScreen(
            library: emptyLibrary, save: save, adService: ads),
        StoryScreen(library: emptyLibrary, save: save, adService: ads),
        ArenaScreen(library: emptyLibrary, save: save, adService: ads),
      ];

  testWidgets('every browsing screen carries exactly one banner',
      (tester) async {
    final s = await services();

    for (final screen in browsingScreens(s.save, s.ads)) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump();

      expect(find.byType(AdBanner), findsOneWidget,
          reason: '${screen.runtimeType} should carry a banner');
    }
    s.ads.dispose();
  });

  testWidgets('the banner never swallows the screen it sits on',
      (tester) async {
    // The regression, stated as a measurement: the banner must stay a strip,
    // and the body must keep almost all of the screen.
    final s = await services();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final screen in browsingScreens(s.save, s.ads)) {
      // Tear the previous screen down first. Without this the outgoing tree
      // lays out one last frame against the incoming screen's constraints and
      // reports an overflow on a widget that no longer exists.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Name the screen that overflowed. A bare "RenderFlex overflowed"
      // says nothing about where to look.
      final layoutError = tester.takeException();
      expect(layoutError, isNull,
          reason: '${screen.runtimeType} overflows at 400x800: $layoutError');

      final banner = tester.getSize(find.byType(AdBanner));
      expect(banner.height, lessThan(120),
          reason: '${screen.runtimeType}: the banner grew to '
              '${banner.height}px and is eating the screen');

      final body = tester.getSize(find.byType(Scaffold).first);
      expect(body.height - banner.height, greaterThan(600),
          reason: '${screen.runtimeType}: only '
              '${body.height - banner.height}px left for the game');
    }
    s.ads.dispose();
  });

  testWidgets('buying Remove Ads takes the banner away everywhere',
      (tester) async {
    final s = await services();
    // A plain field on the save; AdBanner reads adsEnabled on every build.
    s.save.removeAds = true;

    for (final screen in browsingScreens(s.save, s.ads)) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('ad-banner')), findsNothing,
          reason: '${screen.runtimeType} still shows a banner to a player who '
              'paid not to see one');
    }
    s.ads.dispose();
  });
}
