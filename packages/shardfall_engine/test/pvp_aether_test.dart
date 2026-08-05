import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef _unit(String id, {int cost = 2}) => CardDef(
      id: id,
      name: 'Unit $id',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      costGeneric: cost,
      might: 2,
      guard: 2,
    );

CardDef _wellspring(String id) => CardDef(
      id: id,
      name: 'Wellspring $id',
      dominions: const [Dominion.verdance],
      type: CardType.wellspring,
    );

void main() {
  test('playing a unit raises its own Aether in one command', () {
    // The client used to send one exertForAether per Wellspring before the
    // play, so a two-cost card cost three network round trips. That is what
    // made PvP feel sluggish. The server now funds the play itself.
    final hand = [
      CardInstance(instanceId: 1, def: _unit('u', cost: 2), owner: PlayerId.p1),
    ];
    final arena = [
      for (var i = 0; i < 3; i++)
        CardInstance(
          instanceId: 10 + i,
          def: _wellspring('w$i'),
          owner: PlayerId.p1,
        ),
    ];
    final session = PvpSession(
      game: GameState(
        p1: PlayerState(id: PlayerId.p1, hand: hand, arena: arena),
        p2: const PlayerState(id: PlayerId.p2),
        activePlayer: PlayerId.p1,
        phase: Phase.main1,
        rngSeed: 3,
        firstPlayer: PlayerId.p1,
      ),
      stage: PvpStage.main,
      ready: const {PlayerId.p1: true, PlayerId.p2: true},
      mulliganUsed: const {PlayerId.p1: true, PlayerId.p2: true},
      priority: PlayerId.p1,
      passCount: 0,
      resumeStage: PvpStage.main,
      pendingAttackers: const [],
      revision: 0,
    );

    final result = PvpEngine.apply(
      session,
      PlayerId.p1,
      const PvpCommand(
        type: PvpCommandType.playUnit,
        idempotencyKey: 'play',
        revision: 0,
        payload: {'instanceId': 1},
      ),
    );

    expect(result.accepted, isTrue, reason: result.error?.message);
    expect(
      result.session.game.p1.arena.any((c) => c.instanceId == 1),
      isTrue,
      reason: 'the unit reached the board',
    );
    expect(
      result.session.game.p1.arena
          .where((c) => c.def.type == CardType.wellspring && c.exerted)
          .length,
      2,
      reason: 'exactly the Wellsprings needed were tapped',
    );
  });

  test('a play with nothing left to tap is still refused', () {
    final session = PvpSession(
      game: GameState(
        p1: PlayerState(
          id: PlayerId.p1,
          hand: [
            CardInstance(
              instanceId: 1,
              def: _unit('u', cost: 5),
              owner: PlayerId.p1,
            ),
          ],
        ),
        p2: const PlayerState(id: PlayerId.p2),
        activePlayer: PlayerId.p1,
        phase: Phase.main1,
        rngSeed: 3,
        firstPlayer: PlayerId.p1,
      ),
      stage: PvpStage.main,
      ready: const {PlayerId.p1: true, PlayerId.p2: true},
      mulliganUsed: const {PlayerId.p1: true, PlayerId.p2: true},
      priority: PlayerId.p1,
      passCount: 0,
      resumeStage: PvpStage.main,
      pendingAttackers: const [],
      revision: 0,
    );

    final result = PvpEngine.apply(
      session,
      PlayerId.p1,
      const PvpCommand(
        type: PvpCommandType.playUnit,
        idempotencyKey: 'play',
        revision: 0,
        payload: {'instanceId': 1},
      ),
    );

    expect(result.accepted, isFalse, reason: 'Aether must not be invented');
  });
}
