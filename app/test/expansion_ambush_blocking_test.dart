import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/duel/duel_screen.dart';
import 'package:shardfall/services/audio_manager.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = CardLibrary.fromJsonString(
    File('assets/data/set02.json').readAsStringSync(),
  );

  CardInstance defender(String kind) => CardInstance(
    instanceId: 1001,
    def: library.card(kind == 'printed' ? 'SF002-091' : 'SF002-092'),
    owner: PlayerId.p1,
    exerted: true,
    tempKeywords: kind == 'temporary' ? {Keyword.ambush} : const {},
  );

  DuelController battlefield(String kind) {
    final controller = DuelController(
      playerDeck: List.filled(40, library.card('SF002-087')),
      enemyDeck: List.filled(40, library.card('SF002-044')),
      firstPlayer: PlayerId.p2,
      seed: 7,
    );
    controller.state = controller.state
        .withPlayer(
          controller.me.copyWith(health: 2, hand: [], arena: [defender(kind)]),
        )
        .withPlayer(
          controller.foe.copyWith(
            hand: [],
            arena: [
              CardInstance(
                instanceId: 2001,
                // A stable vanilla attack isolates Ambush from card tuning
                // and death payoffs; the defending SF002 units remain real.
                def: const CardDef(
                  id: 'TEST-ATTACKER',
                  name: 'Attacker',
                  dominions: [Dominion.pyre],
                  type: CardType.unit,
                  might: 2,
                  guard: 1,
                ),
                owner: PlayerId.p2,
              ),
            ],
          ),
        );
    return controller;
  }

  void openBlockSelection(DuelController controller) {
    controller.awaitingMulligan = false;
    controller.ui = DuelUiState.playerBlocking;
    controller.incomingAttackers = [2001];
    controller.blockingSelectedAttacker = 2001;
    controller.state = controller.state.copyWith(phase: Phase.combat);
  }

  // Audio is unrelated to blocking. Stub only the native audio boundary;
  // the screen, controller, targeting and combat paths remain real.
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
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
  });

  for (final kind in ['printed', 'temporary', 'ordinary']) {
    final permits = kind != 'ordinary';
    testWidgets(
      '$kind Ambush state controls the actual prompt and lethal block',
      (tester) async {
        final controller = battlefield(kind);
        addTearDown(controller.dispose);
        if (kind == 'printed') {
          expect(controller.me.arena.single.def.name, 'Currentstep Crab');
        } else {
          expect(
            controller.me.arena.single.def.keywords,
            isNot(contains(Keyword.ambush)),
          );
        }
        var prompts = 0;
        unawaited(controller.confirmHand());
        for (var i = 0; i < 120 && controller.busy; i++) {
          if (controller.ui == DuelUiState.playerBlocking) {
            prompts++;
            controller.assignBlocker(1001);
            controller.confirmBlocks();
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(controller.busy, isFalse, reason: 'the enemy turn must unwind');
        expect(prompts, permits ? 1 : 0);
        if (permits) {
          expect(controller.state.winner, isNull);
          expect(
            controller.me.health,
            2,
            reason: 'the exerted unit prevented lethal',
          );
          expect(controller.me.ruins.map((c) => c.instanceId), contains(1001));
          expect(controller.foe.ruins.map((c) => c.instanceId), contains(2001));
          expect(controller.state.activePlayer, PlayerId.p1);
        } else {
          expect(controller.state.winner, PlayerId.p2);
          expect(controller.me.health, 0);
        }
      },
    );

    test('$kind Ambush state controls assignment of an exerted unit', () {
      final controller = battlefield(kind);
      addTearDown(controller.dispose);
      openBlockSelection(controller);
      controller.assignBlocker(1001);
      expect(controller.blockerAssignedTo(1001), permits ? 2001 : isNull);
    });

    testWidgets('$kind Ambush state controls tapping the exerted arena card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = battlefield(kind);
      addTearDown(controller.dispose);
      openBlockSelection(controller);
      await tester.pumpWidget(
        MaterialApp(home: DuelScreen(controller: controller)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('arena1001')));
      await tester.pump();
      expect(controller.blockerAssignedTo(1001), permits ? 2001 : isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
