import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef unitDef(
  String id, {
  int might = 2,
  int guard = 2,
  Set<Keyword> keywords = const {},
  int aegis = 0,
}) =>
    CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.pyre],
      type: CardType.unit,
      might: might,
      guard: guard,
      keywords: keywords,
      aegisValue: aegis,
    );

/// Build a minimal mid-game state with given arenas.
GameState arenaState({
  required List<CardInstance> p1Arena,
  required List<CardInstance> p2Arena,
}) =>
    GameState(
      p1: PlayerState(id: PlayerId.p1, arena: p1Arena),
      p2: PlayerState(id: PlayerId.p2, arena: p2Arena),
      rngSeed: 0,
      phase: Phase.combat,
    );

CardInstance inst(int id, CardDef def, PlayerId owner) =>
    CardInstance(instanceId: id, def: def, owner: owner);

void main() {
  group('declare attackers', () {
    test('attacking exerts unless Alert', () {
      final s = arenaState(p1Arena: [
        inst(1, unitDef('A'), PlayerId.p1),
        inst(2, unitDef('B', keywords: {Keyword.alert}), PlayerId.p1),
      ], p2Arena: []);
      final after = Combat.declareAttackers(s, PlayerId.p1, [1, 2]);
      expect(after.p1.arena[0].exerted, isTrue);
      expect(after.p1.arena[1].exerted, isFalse);
    });

    test('Bulwark cannot attack; summoning fatigue enforced', () {
      final s = arenaState(p1Arena: [
        inst(1, unitDef('Wall', keywords: {Keyword.bulwark}), PlayerId.p1),
        inst(2, unitDef('Fresh'), PlayerId.p1).copyWith(summonedThisTurn: true),
      ], p2Arena: []);
      expect(() => Combat.declareAttackers(s, PlayerId.p1, [1]),
          throwsStateError);
      expect(() => Combat.declareAttackers(s, PlayerId.p1, [2]),
          throwsStateError);
    });
  });

  group('block validation', () {
    test('Soar only blockable by Soar or Intercept', () {
      final s = arenaState(p1Arena: [
        inst(1, unitDef('Flyer', keywords: {Keyword.soar}), PlayerId.p1),
      ], p2Arena: [
        inst(2, unitDef('Ground'), PlayerId.p2),
        inst(3, unitDef('Archer', keywords: {Keyword.intercept}), PlayerId.p2),
      ]);
      expect(
        () => Combat.resolveDamage(s, PlayerId.p1,
            [const AttackDeclaration(attackerId: 1, blockerIds: [2])]),
        throwsStateError,
      );
      final ok = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [3])]);
      expect(ok.winner, isNull);
    });

    test('Dread requires 2+ blockers', () {
      final s = arenaState(p1Arena: [
        inst(1, unitDef('Scary', keywords: {Keyword.dread}), PlayerId.p1),
      ], p2Arena: [
        inst(2, unitDef('B1'), PlayerId.p2),
        inst(3, unitDef('B2'), PlayerId.p2),
      ]);
      expect(
        () => Combat.resolveDamage(s, PlayerId.p1,
            [const AttackDeclaration(attackerId: 1, blockerIds: [2])]),
        throwsStateError,
      );
      final ok = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2, 3])]);
      expect(ok.winner, isNull);
    });

    test('Aegis N prevents N combat damage', () {
      // 3/3 attacker vs 3/3 blocker with Aegis 2: blocker takes 3-2=1 and
      // survives; attacker takes full 3 and dies. Without Aegis both die.
      final s = arenaState(p1Arena: [
        inst(1, unitDef('Atk', might: 3, guard: 3), PlayerId.p1),
      ], p2Arena: [
        inst(2, unitDef('Warded', might: 3, guard: 3, aegis: 2), PlayerId.p2),
      ]);
      final after = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
      // Warded blocker survived with 1 damage; attacker died.
      expect(after.p2.arena.where((c) => c.instanceId == 2), isNotEmpty);
      expect(after.p2.arena.firstWhere((c) => c.instanceId == 2).damage, 1);
      expect(after.p1.arena.where((c) => c.instanceId == 1), isEmpty);
    });
  });

  test('end of turn clears block damage on the defending player too', () {
    // Defender's unit survives with damage from blocking on the attacker turn.
    var s = arenaState(
      p1Arena: [inst(1, unitDef('Atk', might: 2, guard: 3), PlayerId.p1)],
      p2Arena: [inst(2, unitDef('Blocker', might: 1, guard: 4), PlayerId.p2)],
    );
    s = Combat.resolveDamage(s, PlayerId.p1,
        [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
    expect(s.p2.arena.first.damage, 2, reason: 'blocker took 2');
    // End P1's turn → cleanup should heal BOTH sides.
    s = Game.nextPhase(s); // combat -> main2 (phase was combat)
    // Force to end and wrap.
    var guard = 0;
    while (s.phase != Phase.refresh && guard < 10) {
      s = Game.nextPhase(s);
      guard++;
    }
    expect(s.p2.arena.first.damage, 0,
        reason: 'block damage cleared at end of turn');
  });

  group('damage resolution', () {
    test('unblocked attacker hits player; lethal sets winner', () {
      final s = arenaState(
        p1Arena: [inst(1, unitDef('Big', might: 30), PlayerId.p1)],
        p2Arena: [],
      );
      final after = Combat.resolveDamage(
          s, PlayerId.p1, [const AttackDeclaration(attackerId: 1)]);
      expect(after.p2.health, lessThanOrEqualTo(0));
      expect(after.winner, PlayerId.p1);
    });

    test('mutual trade: both units die and go to ruins', () {
      final s = arenaState(
        p1Arena: [inst(1, unitDef('A', might: 2, guard: 2), PlayerId.p1)],
        p2Arena: [inst(2, unitDef('B', might: 2, guard: 2), PlayerId.p2)],
      );
      final after = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
      expect(after.p1.arena, isEmpty);
      expect(after.p2.arena, isEmpty);
      expect(after.p1.ruins.length, 1);
      expect(after.p2.ruins.length, 1);
    });

    test('Swiftstrike kills blocker before it strikes back', () {
      final s = arenaState(
        p1Arena: [
          inst(1, unitDef('Duelist', might: 2, guard: 1, keywords: {Keyword.swiftstrike}), PlayerId.p1)
        ],
        p2Arena: [inst(2, unitDef('Brute', might: 5, guard: 2), PlayerId.p2)],
      );
      final after = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
      expect(after.p1.arena.length, 1, reason: 'duelist survives');
      expect(after.p2.arena, isEmpty, reason: 'brute died to swiftstrike');
    });

    test('Venom destroys blocker with 1 damage; Rampage carries excess', () {
      final s = arenaState(
        p1Arena: [
          inst(1, unitDef('Serpent', might: 4, guard: 3, keywords: {Keyword.venom, Keyword.rampage}), PlayerId.p1)
        ],
        p2Arena: [inst(2, unitDef('Tower', might: 0, guard: 8), PlayerId.p2)],
      );
      final after = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
      expect(after.p2.arena, isEmpty, reason: 'venom kills the 8-guard tower');
      expect(after.p2.health, 25 - 3, reason: 'venom assigns 1, rampage carries 3');
    });

    test('Leech heals controller for damage dealt', () {
      final s = arenaState(
        p1Arena: [
          inst(1, unitDef('Vampire', might: 3, keywords: {Keyword.leech}), PlayerId.p1)
        ],
        p2Arena: [],
      );
      final after = Combat.resolveDamage(
          s, PlayerId.p1, [const AttackDeclaration(attackerId: 1)]);
      expect(after.p1.health, 28);
      expect(after.p2.health, 22);
    });

    test('multi-block damage assignment in order', () {
      final s = arenaState(
        p1Arena: [inst(1, unitDef('Giant', might: 5, guard: 5), PlayerId.p1)],
        p2Arena: [
          inst(2, unitDef('Chump1', might: 1, guard: 2), PlayerId.p2),
          inst(3, unitDef('Chump2', might: 1, guard: 4), PlayerId.p2),
        ],
      );
      final after = Combat.resolveDamage(s, PlayerId.p1,
          [const AttackDeclaration(attackerId: 1, blockerIds: [2, 3])]);
      expect(after.p2.arena.length, 1, reason: 'chump1 dies, chump2 survives');
      expect(after.p2.arena.first.damage, 3);
      expect(after.p2.health, 25, reason: 'no rampage, no player damage');
    });
  });
}
