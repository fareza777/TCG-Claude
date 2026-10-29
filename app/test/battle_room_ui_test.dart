import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/battle_rooms/battle_room_background.dart';
import 'package:shardfall/battle_rooms/battle_room_catalog.dart';
import 'package:shardfall/battle_rooms/battle_room_selection.dart';
import 'package:shardfall/battle_rooms/battle_room_shop.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/duel/duel_screen.dart';
import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/audio_manager.dart';
import 'package:shardfall/services/haptics.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/theme.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

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

class _RefreshingDuel extends DuelController {
  _RefreshingDuel(List<CardDef> deck)
    : super(playerDeck: deck, enemyDeck: deck, seed: 7);
  void changeHealth() {
    state = state.withPlayer(me.copyWith(health: me.health + 1));
    notifyListeners();
  }
}

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  setUp(() {
    AudioManager.instance.musicOn = false;
    AudioManager.instance.sfxOn = false;
    AudioManager.instance.voiceOn = false;
    Haptics.enabled = false;
    BattleRoomSelection.active.value = BattleRooms.classic;
  });
  Future<SaveService> profile(int gold) async {
    SharedPreferences.setMockInitialValues({
      'gold': gold,
      'lastLoginDate': DateTime.now().toIso8601String().substring(0, 10),
    });
    return SaveService.load(library);
  }

  testWidgets(
    '320px shop previews without spending, confirms purchase, equips and reverts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final save = await profile(600);
      final ads = AdService(save: save, platform: _NoAds());
      addTearDown(ads.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BattleRoomShopScreen(
            library: library,
            save: save,
            adService: ads,
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('preview-moonroot')),
      );
      await tester.tap(find.byKey(const ValueKey('preview-moonroot')));
      await tester.pumpAndSettle();
      expect(find.text('ROOM PREVIEW'), findsOneWidget);
      expect(save.gold, 600);
      expect(save.equippedBattleRoom, 'classic');
      expect(BattleRoomSelection.active.value.id, 'classic');
      expect(
        find.byKey(const ValueKey('battle-room-moonroot')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('buy-moonroot')));
      await tester.tap(find.byKey(const ValueKey('buy-moonroot')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(save.gold, 600);
      await tester.tap(find.byKey(const ValueKey('buy-moonroot')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-room-purchase')));
      await tester.pumpAndSettle();
      expect(save.gold, 0);
      expect(save.equippedBattleRoom, 'moonroot');
      expect(find.text('EQUIPPED'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('equip-classic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('equip-classic')));
      await tester.pumpAndSettle();
      expect(save.equippedBattleRoom, 'classic');
      expect(save.gold, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'unaffordable rooms show their Gold shortfall and remain previewable',
    (tester) async {
      final save = await profile(140);
      final ads = AdService(save: save, platform: _NoAds());
      addTearDown(ads.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BattleRoomShopScreen(
            library: library,
            save: save,
            adService: ads,
          ),
        ),
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('buy-moonroot')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Need 460 more Gold'), findsWidgets);
      expect(save.gold, 140);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'long enemy names keep battle-header controls visible on a small phone',
    (tester) async {
      for (final family in ['Cinzel', 'EBGaramond']) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
      }
      for (final family in ['serif', 'Georgia']) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/EBGaramond.ttf'))).load();
      }
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _RefreshingDuel(library.buildStarterDeck('VERDANCE'));
      addTearDown(controller.dispose);
      controller.awaitingMulligan = false;
      controller.ui = DuelUiState.enemyTurn;
      const name = 'The Keeper of Every Unspoken Promise Beyond the Tide';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: DuelScreen(controller: controller, enemyName: name),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final history = find.byIcon(Icons.history);
      expect(tester.getCenter(history).dx, inExclusiveRange(0, 320));
      await tester.tap(history);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Battle log'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'real duel uses the selected room with no rules-state change or extra background paints',
    (tester) async {
      final save = await profile(600);
      await save.purchaseBattleRoom('tideglass');
      final controller = _RefreshingDuel(library.buildStarterDeck('VERDANCE'));
      addTearDown(controller.dispose);
      final game = controller.state;
      await tester.pumpWidget(
        MaterialApp(home: DuelScreen(controller: controller)),
      );
      await tester.runAsync(
        () => precacheImage(
          BattleRoomBackground.imageProvider(BattleRooms.find('tideglass')!),
          tester.element(find.byType(DuelScreen)),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state, same(game));
      final finder = find.byKey(const ValueKey('battle-room-tideglass'));
      expect(finder, findsOneWidget);
      final layer = tester.renderObject<RenderRepaintBoundary>(finder);
      final paints = layer.debugSymmetricPaintCount;
      final retainedPicture = layer.debugLayer?.firstChild;
      expect(retainedPicture, isNotNull);
      for (var i = 0; i < 100; i++) {
        controller.changeHealth();
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        layer.debugSymmetricPaintCount,
        paints,
        reason: 'turn updates must not repaint the static illustrated room',
      );
      expect(
        layer.debugLayer?.firstChild,
        same(retainedPicture),
        reason: 'the recorded background picture must be reused across updates',
      );
      final image = tester.widget<Image>(
        find.descendant(of: finder, matching: find.byType(Image)),
      );
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, lessThanOrEqualTo(1280));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
