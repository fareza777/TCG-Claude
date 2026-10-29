import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

const _unit = CardDef(
  id: 'SF002-001',
  name: 'Vowkeeper',
  dominions: [Dominion.verdance],
  type: CardType.unit,
  might: 2,
  guard: 4,
);
const _spring = CardDef(
  id: 'SF002-002',
  name: 'Spring',
  dominions: [Dominion.verdance],
  type: CardType.wellspring,
);
CardDef _renew(String owner) => CardDef(
  id: 'SF002-003',
  name: 'Renew',
  dominions: const [Dominion.verdance],
  type: CardType.rite,
  effects: [
    {
      'trigger': 'ON_CAST',
      'effects': [
        {
          'op': 'RENEW',
          'amount': 2,
          'target': {
            'select': 'CHOOSE',
            'owner': owner,
            'filter': {'type': 'UNIT'},
          },
        },
      ],
    },
  ],
);

void main() {
  late DuelController controller;
  setUp(() {
    controller = DuelController(
      playerDeck: List.filled(40, _unit),
      enemyDeck: List.filled(40, _unit),
      seed: 5,
    );
    controller.state = controller.state
        .withPlayer(
          controller.me.copyWith(
            arena: [
              CardInstance(instanceId: 1001, def: _unit, owner: PlayerId.p1),
              CardInstance(instanceId: 1002, def: _spring, owner: PlayerId.p1),
            ],
            hand: [
              ...controller.me.hand,
              CardInstance(
                instanceId: 3001,
                def: _renew('SELF'),
                owner: PlayerId.p1,
              ),
            ],
          ),
        )
        .withPlayer(
          controller.foe.copyWith(
            arena: [
              CardInstance(instanceId: 2001, def: _unit, owner: PlayerId.p2),
            ],
          ),
        );
  });
  tearDown(() => controller.dispose());

  test('Renew only aims at friendly units and rejects wrong-side clicks', () {
    final def = _renew('SELF');
    expect(controller.canTargetUnit(def, 1001), isTrue);
    expect(controller.canTargetUnit(def, 1002), isFalse);
    expect(controller.canTargetUnit(def, 2001), isFalse);
    expect(controller.canTargetUnit(def, 9999), isFalse);
    expect(controller.targetSpec(def).friendly, isTrue);
    controller.playHandCard(3001);
    controller.selectUnitTarget(2001);
    expect(controller.targetingId, 3001);
    expect(controller.me.hand.any((card) => card.instanceId == 3001), isTrue);
  });

  test(
    'an enemy board cannot make a friendly Renew castable without allies',
    () {
      controller.state = controller.state.withPlayer(
        controller.me.copyWith(arena: []),
      );
      expect(controller.hasLegalTarget(_renew('SELF')), isFalse);
      expect(controller.hasLegalTarget(_renew('OPPONENT')), isTrue);
      controller.playHandCard(3001);
      expect(controller.isTargeting, isFalse);
      expect(controller.lastError, contains('No legal targets'));
    },
  );

  test('one selected ally receives both compatible chosen effects', () {
    final target = {
      'select': 'CHOOSE',
      'owner': 'SELF',
      'filter': {'type': 'UNIT'},
    };
    final card = CardDef(
      id: 'SF002-004',
      name: 'Unbroken Shelter',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      might: 2,
      guard: 3,
      effects: [
        {
          'trigger': 'ON_ENTER_ARENA',
          'effects': [
            {'op': 'ADD_COUNTER', 'amount': 1, 'target': target},
            {'op': 'BUFF', 'might': 2, 'guard': 2, 'target': target},
          ],
        },
      ],
    );
    controller.state = controller.state.withPlayer(
      controller.me.copyWith(
        hand: [
          ...controller.me.hand,
          CardInstance(instanceId: 3002, def: card, owner: PlayerId.p1),
        ],
      ),
    );
    controller.playHandCard(3002);
    controller.selectUnitTarget(1001);
    final ally = controller.me.arena.singleWhere((c) => c.instanceId == 1001);
    expect(ally.plusCounters, 1);
    expect(ally.tempMight, 2);
    expect(ally.tempGuard, 2);
  });
}
