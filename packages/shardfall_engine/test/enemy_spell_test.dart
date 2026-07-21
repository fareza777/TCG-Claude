import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef spearDef() => const CardDef(
      id: 'MS',
      name: 'Molten Spear',
      dominions: [Dominion.pyre],
      type: CardType.rite,
      costDominion: {Dominion.pyre: 1},
      text: 'Deal 3 damage to target Unit.',
      effects: [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {
              'op': 'DEAL_DAMAGE',
              'amount': 3,
              'target': {'select': 'CHOOSE'},
            }
          ],
        }
      ],
    );

CardDef boltDef() => const CardDef(
      id: 'CB',
      name: 'Cinder Bolt',
      dominions: [Dominion.pyre],
      type: CardType.rite,
      costDominion: {Dominion.pyre: 1},
      text: 'Deal 2 damage to any target.',
      effects: [
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

CardDef targetUnitDef() => const CardDef(
      id: 'GRUNT',
      name: 'Grunt',
      dominions: [Dominion.verdance],
      type: CardType.unit,
      might: 2,
      guard: 5,
    );

void main() {
  test('enemy AI casts a targeted damage spell and it hits my unit', () {
    final state = GameState(
      p1: PlayerState(id: PlayerId.p1, arena: [
        CardInstance(instanceId: 1, def: targetUnitDef(), owner: PlayerId.p1),
      ]),
      p2: PlayerState(
        id: PlayerId.p2,
        hand: [
          CardInstance(instanceId: 100, def: spearDef(), owner: PlayerId.p2),
        ],
        aetherPool: const {Dominion.pyre: 3},
      ),
      activePlayer: PlayerId.p2,
      phase: Phase.main1,
      rngSeed: 0,
    );

    const ai = AiPlayer(tier: AiTier.tactician);
    final sp = ai.nextSpell(state, PlayerId.p2);
    expect(sp, isNotNull, reason: 'AI should choose to cast the spear');
    expect(sp!.unitTargetId, 1, reason: 'aim at my only unit');

    final next = Chain.resolveAll(
        Chain.cast(state, PlayerId.p2, sp.cardId, targets: sp.targets));
    final myUnit = next.p1.arena.firstWhere((c) => c.instanceId == 1);
    expect(myUnit.damage, 3, reason: 'my unit should take 3 damage');
  });

  test('enemy AI casts an any-target bolt at my unit', () {
    final state = GameState(
      p1: PlayerState(id: PlayerId.p1, arena: [
        CardInstance(instanceId: 1, def: targetUnitDef(), owner: PlayerId.p1),
      ]),
      p2: PlayerState(
        id: PlayerId.p2,
        hand: [
          CardInstance(instanceId: 100, def: boltDef(), owner: PlayerId.p2),
        ],
        aetherPool: const {Dominion.pyre: 3},
      ),
      activePlayer: PlayerId.p2,
      phase: Phase.main1,
      rngSeed: 0,
    );

    const ai = AiPlayer(tier: AiTier.tactician);
    final sp = ai.nextSpell(state, PlayerId.p2);
    expect(sp, isNotNull);
    final next = Chain.resolveAll(
        Chain.cast(state, PlayerId.p2, sp!.cardId, targets: sp.targets));
    final myUnit = next.p1.arena.firstWhere((c) => c.instanceId == 1);
    expect(myUnit.damage, 2, reason: 'my unit should take 2 damage');
  });
}
