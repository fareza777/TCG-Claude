// Explicit visual-proof task, outside the default unit-test directory.
// flutter test --no-pub tool/battle_room_visual_proof_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall/battle_rooms/battle_room_catalog.dart';
import 'package:shardfall/battle_rooms/battle_room_shop.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/duel/duel_screen.dart';
import 'package:shardfall/duel/scenario.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
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
    AudioManager.instance.musicOn = false;
    AudioManager.instance.sfxOn = false;
    AudioManager.instance.voiceOn = false;
    Haptics.enabled = false;
    for (final family in ['Cinzel', 'EBGaramond']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    // Match the local desktop serif fallback instead of the test Ahem font.
    final georgia = File(
      '${Platform.environment['WINDIR'] ?? r'C:\Windows'}/Fonts/georgia.ttf',
    );
    final bytes = georgia.existsSync()
        ? georgia.readAsBytesSync()
        : File('assets/fonts/EBGaramond.ttf').readAsBytesSync();
    for (final family in ['serif', 'Georgia']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final flutterFont = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (flutterFont.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(flutterFont.readAsBytesSync())),
          ))
          .load();
    }
  });

  testWidgets('capture real Flutter shop and all four paused battle rooms', (
    tester,
  ) async {
    final library = CardLibrary.fromJsonStrings([
      File('assets/data/set01.json').readAsStringSync(),
      File('assets/data/set02.json').readAsStringSync(),
    ]);
    // This explicit flutter_test task lives outside test/ to avoid PNG writes
    // during the normal suite. Its preferences are a test-only profile.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'gold': 1800,
      'lastLoginDate': DateTime.now().toIso8601String().substring(0, 10),
    });
    final save = await SaveService.load(library);
    final ads = AdService(save: save, platform: _NoAds());
    addTearDown(ads.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final directory = Directory('../docs/expansion/previews')
      ..createSync(recursive: true);

    Future<void> capture(Widget screen, Size size, String name) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('proof-root'),
          child: MaterialApp(
            theme: AppTheme.build(),
            debugShowCheckedModeBanner: false,
            home: screen,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(
          find.byKey(const ValueKey('proof-root')),
        );
        final providers = tester
            .widgetList<Image>(find.byType(Image))
            .map((i) => i.image)
            .toSet();
        await Future.wait(providers.map((p) => precacheImage(p, context)));
      });
      await tester.pumpAndSettle();
      final renderingError = tester.takeException();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('proof-root')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(renderingError, isNull, reason: name);
    }

    await capture(
      BattleRoomShopScreen(library: library, save: save, adService: ads),
      const Size(1120, 1180),
      'battle-room-shop-0.2.2',
    );
    await capture(
      BattleRoomShopScreen(library: library, save: save, adService: ads),
      const Size(390, 844),
      'battle-room-shop-phone-0.2.2',
    );
    for (final room in BattleRooms.premium) {
      expect(
        await save.purchaseBattleRoom(room.id),
        RoomPurchaseResult.purchased,
      );
    }
    for (final room in BattleRooms.all) {
      await save.equipBattleRoom(room.id);
      final verdanceWell = library.card(
        library.starterDecks['VERDANCE']!.wellspringId,
      );
      final tideWell = library.card(library.starterDecks['TIDE']!.wellspringId);
      final scenario = BattleScenario(
        playerBoard: [
          library.card('SF002-004'),
          library.card('SF002-007'),
          for (var i = 0; i < 3; i++) verdanceWell,
        ],
        enemyBoard: [
          library.card('SF002-091'),
          library.card('SF002-095'),
          for (var i = 0; i < 3; i++) tideWell,
        ],
      );
      final controller = DuelController(
        playerDeck: library.buildStarterDeck('VERDANCE'),
        enemyDeck: library.buildStarterDeck('TIDE'),
        scenario: scenario,
        seed: 7,
      );
      controller.awaitingMulligan = false;
      controller.ui = DuelUiState.playerMain;
      controller.state = controller.state.copyWith(
        phase: Phase.main1,
        turnNumber: 4,
      );
      await capture(
        DuelScreen(controller: controller, enemyName: 'Tideglass Keeper'),
        const Size(390, 844),
        'battle-room-${room.id}-0.2.2',
      );
      if (room.id == 'tideglass') {
        await capture(
          DuelScreen(controller: controller, enemyName: 'Tideglass Keeper'),
          const Size(1280, 720),
          'battle-room-wide-0.2.2',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}
