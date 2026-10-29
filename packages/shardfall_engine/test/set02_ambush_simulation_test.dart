import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

void main() {
  test('autonomous combat permits an exerted Currentstep Crab to block', () {
    final lib = CardLibrary.fromJsonString(
        File('../../data/cards/set02.json').readAsStringSync());
    final state = GameState(
      p1: PlayerState(id: PlayerId.p1, arena: [
        CardInstance(
            instanceId: 1, def: lib.card('SF002-045'), owner: PlayerId.p1),
      ]),
      p2: PlayerState(id: PlayerId.p2, health: 2, arena: [
        CardInstance(
            instanceId: 2,
            def: lib.card('SF002-091'),
            owner: PlayerId.p2,
            exerted: true),
      ]),
      rngSeed: 7,
      phase: Phase.main1,
      nextInstanceId: 3,
    );
    final after = const AiPlayer().playTurn(state, PlayerId.p1,
        defenderAi: const AiPlayer(tier: AiTier.tactician));
    expect(after.winner, isNull);
    expect(after.p2.health, 2);
    expect(after.p1.ruins.single.instanceId, 1);
    expect(after.p2.ruins.single.instanceId, 2);
  });
}
