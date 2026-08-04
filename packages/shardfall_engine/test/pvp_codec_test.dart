import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef _unit(String id) => CardDef(
      id: id,
      name: 'Unit $id',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      costDominion: const {Dominion.verdance: 1},
      might: 3,
      guard: 4,
      keywords: const {Keyword.alert},
      text: 'A test unit',
    );

CardDef _wellspring(String id) => CardDef(
      id: id,
      name: 'Wellspring $id',
      dominions: const [Dominion.verdance],
      type: CardType.wellspring,
    );

CardDef _rite(String id) => CardDef(
      id: id,
      name: 'Rite $id',
      dominions: const [Dominion.verdance],
      type: CardType.rite,
      effects: const [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {
              'op': 'DRAW',
              'count': 1,
              'target': {'select': 'SELF_PLAYER'},
            },
          ],
        },
      ],
    );

void main() {
  final library = CardLibrary(
    byId: {
      'u1': _unit('u1'),
      'u2': _unit('u2'),
      'ws1': _wellspring('ws1'),
      'rite1': _rite('rite1'),
    },
    starterDecks: const {},
  );

  final original = PvpSession(
    game: GameState(
      p1: PlayerState(
        id: PlayerId.p1,
        health: 21,
        deck: [
          CardInstance(
              instanceId: 31, def: library.card('u1'), owner: PlayerId.p1),
        ],
        hand: [
          CardInstance(
            instanceId: 11,
            def: library.card('u1'),
            owner: PlayerId.p1,
            exerted: true,
            damage: 2,
            plusCounters: 1,
            summonedThisTurn: true,
            tempMight: 2,
            tempGuard: -1,
            tempKeywords: const {Keyword.rush},
          ),
        ],
        arena: [
          CardInstance(
              instanceId: 12, def: library.card('ws1'), owner: PlayerId.p1),
        ],
        aetherPool: const {Dominion.verdance: 2},
        playedWellspringThisTurn: true,
        usedAttuneThisTurn: true,
      ),
      p2: PlayerState(
        id: PlayerId.p2,
        hand: [
          CardInstance(
              instanceId: 21, def: library.card('rite1'), owner: PlayerId.p2),
        ],
        arena: [
          CardInstance(
              instanceId: 22, def: library.card('u2'), owner: PlayerId.p2),
        ],
      ),
      activePlayer: PlayerId.p2,
      phase: Phase.combat,
      turnNumber: 4,
      nextInstanceId: 40,
      rngSeed: 987654,
      winner: PlayerId.p1,
      chain: [
        ChainItem(
          source: CardInstance(
            instanceId: 21,
            def: library.card('rite1'),
            owner: PlayerId.p2,
          ),
          controller: PlayerId.p2,
          triggerBlock: const {
            'trigger': 'ON_CAST',
            'effects': [
              {
                'op': 'DRAW',
                'count': 1,
                'target': {'select': 'SELF_PLAYER'},
              },
            ],
          },
          chosenTargets: const [
            EffectTarget.unit(12),
            EffectTarget.player(PlayerId.p1),
          ],
          uncounterable: true,
          countered: true,
        ),
      ],
      firstPlayer: PlayerId.p1,
    ),
    stage: PvpStage.chainPriority,
    ready: const {PlayerId.p1: true, PlayerId.p2: true},
    mulliganUsed: const {PlayerId.p1: false, PlayerId.p2: true},
    priority: PlayerId.p1,
    passCount: 1,
    resumeStage: PvpStage.main,
    pendingAttackers: const [12],
    revision: 9,
  );

  test('session codec preserves full authoritative state', () {
    final encoded = PvpCodec.encodeSession(original);
    final decoded = PvpCodec.decodeSession(encoded, library);

    expect(decoded.stage, PvpStage.chainPriority);
    expect(decoded.ready[PlayerId.p1], isTrue);
    expect(decoded.mulliganUsed[PlayerId.p2], isTrue);
    expect(decoded.priority, PlayerId.p1);
    expect(decoded.passCount, 1);
    expect(decoded.pendingAttackers, [12]);
    expect(decoded.revision, 9);

    final game = decoded.game;
    expect(game.activePlayer, PlayerId.p2);
    expect(game.phase, Phase.combat);
    expect(game.turnNumber, 4);
    expect(game.nextInstanceId, 40);
    expect(game.rngSeed, 987654);
    expect(game.winner, PlayerId.p1);
    expect(game.p1.health, 21);
    expect(game.p1.hand.single.instanceId, 11);
    expect(game.p1.hand.single.exerted, isTrue);
    expect(game.p1.hand.single.damage, 2);
    expect(game.p1.hand.single.plusCounters, 1);
    expect(game.p1.hand.single.tempMight, 2);
    expect(game.p1.hand.single.tempGuard, -1);
    expect(game.p1.hand.single.tempKeywords, contains(Keyword.rush));
    expect(game.p1.aetherPool[Dominion.verdance], 2);
    expect(game.chain.single.chosenTargets, hasLength(2));
    expect((game.chain.single.chosenTargets[0] as EffectTarget).instanceId, 12);
    expect((game.chain.single.chosenTargets[1] as EffectTarget).playerId,
        PlayerId.p1);
    expect(game.chain.single.uncounterable, isTrue);
    expect(game.chain.single.countered, isTrue);
  });

  test('player projection redacts opponent hidden information', () {
    final projection = PvpCodec.encodeProjection(original, PlayerId.p1);
    final players = projection['players'] as Map<String, dynamic>;
    final own = players['p1'] as Map<String, dynamic>;
    final opponent = players['p2'] as Map<String, dynamic>;

    expect((own['hand'] as List), hasLength(1));
    expect(opponent['hand'], isEmpty);
    expect(opponent['handCount'], 1);
    expect(projection.containsKey('rngSeed'), isFalse);
    expect(projection.toString(), isNot(contains('987654')));
    expect((opponent['deck'] as List), isEmpty);
    expect(opponent['deckCount'], 0);
    expect((opponent['arena'] as List).single['cardId'], 'u2');
  });
}
