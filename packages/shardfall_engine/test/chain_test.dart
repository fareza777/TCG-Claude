import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef riteDef(String id, {Map<Dominion, int> cost = const {}}) => CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.pyre],
      type: CardType.rite,
      costDominion: cost,
      effects: const [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {
              'op': 'DEAL_DAMAGE',
              'amount': 2,
              'target': {'select': 'CHOOSE'},
            }
          ],
        }
      ],
    );

CardDef ritualDef(String id) => CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.verdance],
      type: CardType.ritual,
      effects: const [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {'op': 'DRAW', 'amount': 1},
          ],
        }
      ],
    );

CardDef unitDef(String id, {int guard = 2}) => CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.tide],
      type: CardType.unit,
      might: 2,
      guard: guard,
    );

void main() {
  GameState setup() {
    final bolt = CardInstance(
        instanceId: 1, def: riteDef('Bolt'), owner: PlayerId.p1);
    final target = CardInstance(
        instanceId: 2, def: unitDef('Chump'), owner: PlayerId.p2);
    final deckTop = CardInstance(
        instanceId: 3, def: unitDef('Top'), owner: PlayerId.p1);
    return GameState(
      p1: PlayerState(id: PlayerId.p1, hand: [bolt], deck: [deckTop]),
      p2: PlayerState(id: PlayerId.p2, arena: [target]),
      rngSeed: 0,
      phase: Phase.main1,
    );
  }

  test('cast rite → chain has one item, card leaves hand', () {
    var s = setup();
    s = Chain.cast(s, PlayerId.p1, 1,
        targets: const [EffectTarget.unit(2)]);
    expect(s.chain.length, 1);
    expect(s.p1.hand, isEmpty);
  });

  test('resolveTop applies damage and moves spell to ruins', () {
    var s = setup();
    s = Chain.cast(s, PlayerId.p1, 1, targets: const [EffectTarget.unit(2)]);
    s = Chain.resolveTop(s);
    expect(s.chain, isEmpty);
    expect(s.p2.arena, isEmpty, reason: '2 damage kills 2-guard unit');
    expect(s.p1.ruins.length, 1, reason: 'bolt in ruins');
  });

  test('countered spell fizzles but still goes to ruins', () {
    var s = setup();
    s = Chain.cast(s, PlayerId.p1, 1, targets: const [EffectTarget.unit(2)]);
    s = Chain.counter(s, 0);
    s = Chain.resolveTop(s);
    expect(s.p2.arena.length, 1, reason: 'target survives');
    expect(s.p1.ruins.length, 1);
  });

  test('uncounterable spell rejects counter', () {
    final wyrmSpell = CardDef(
      id: 'W',
      name: 'Wyrm',
      dominions: const [Dominion.tide],
      type: CardType.rite,
      effects: const [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {'op': 'UNCOUNTERABLE'},
            {'op': 'DRAW', 'amount': 1},
          ],
        }
      ],
    );
    var s = GameState(
      p1: PlayerState(id: PlayerId.p1, hand: [
        CardInstance(instanceId: 1, def: wyrmSpell, owner: PlayerId.p1)
      ], deck: [
        CardInstance(instanceId: 9, def: unitDef('X'), owner: PlayerId.p1)
      ]),
      p2: const PlayerState(id: PlayerId.p2),
      rngSeed: 0,
      phase: Phase.main1,
    );
    s = Chain.cast(s, PlayerId.p1, 1);
    expect(() => Chain.counter(s, 0), throwsStateError);
  });

  test('LIFO: response resolves before original spell', () {
    // P1 casts bolt at P2 unit; P2 responds with their own bolt at P1 unit.
    final p1Bolt =
        CardInstance(instanceId: 1, def: riteDef('P1Bolt'), owner: PlayerId.p1);
    final p2Bolt =
        CardInstance(instanceId: 2, def: riteDef('P2Bolt'), owner: PlayerId.p2);
    final p1Unit =
        CardInstance(instanceId: 3, def: unitDef('P1U'), owner: PlayerId.p1);
    final p2Unit =
        CardInstance(instanceId: 4, def: unitDef('P2U'), owner: PlayerId.p2);
    var s = GameState(
      p1: PlayerState(id: PlayerId.p1, hand: [p1Bolt], arena: [p1Unit]),
      p2: PlayerState(id: PlayerId.p2, hand: [p2Bolt], arena: [p2Unit]),
      rngSeed: 0,
      phase: Phase.main1,
    );
    s = Chain.cast(s, PlayerId.p1, 1, targets: const [EffectTarget.unit(4)]);
    s = Chain.cast(s, PlayerId.p2, 2, targets: const [EffectTarget.unit(3)]);
    expect(s.chain.length, 2);
    s = Chain.resolveAll(s);
    expect(s.p1.arena, isEmpty, reason: 'P2 response resolved first');
    expect(s.p2.arena, isEmpty, reason: 'then P1 bolt resolved');
  });

  test('ritual illegal on non-empty chain', () {
    final bolt =
        CardInstance(instanceId: 1, def: riteDef('Bolt'), owner: PlayerId.p1);
    final ritual = CardInstance(
        instanceId: 2, def: ritualDef('Growth'), owner: PlayerId.p1);
    final tgt =
        CardInstance(instanceId: 3, def: unitDef('T'), owner: PlayerId.p2);
    var s = GameState(
      p1: PlayerState(id: PlayerId.p1, hand: [bolt, ritual]),
      p2: PlayerState(id: PlayerId.p2, arena: [tgt]),
      rngSeed: 0,
      phase: Phase.main1,
    );
    s = Chain.cast(s, PlayerId.p1, 1, targets: const [EffectTarget.unit(3)]);
    expect(() => Chain.cast(s, PlayerId.p1, 2), throwsStateError);
  });

  test('ritual illegal on opponent turn', () {
    final ritual = CardInstance(
        instanceId: 1, def: ritualDef('Growth'), owner: PlayerId.p2);
    final s = GameState(
      p1: const PlayerState(id: PlayerId.p1),
      p2: PlayerState(id: PlayerId.p2, hand: [ritual]),
      rngSeed: 0,
      phase: Phase.main1,
      activePlayer: PlayerId.p1,
    );
    expect(() => Chain.cast(s, PlayerId.p2, 1), throwsStateError);
  });
}
