import 'dart:convert';
import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardInstance unit(CardDef def, int id, PlayerId owner, {int damage = 0}) =>
    CardInstance(instanceId: id, def: def, owner: owner, damage: damage);
PvpSession session(GameState s) => PvpSession(
    game: s,
    stage: PvpStage.main,
    ready: const {},
    mulliganUsed: const {},
    priority: PlayerId.p1,
    passCount: 0,
    resumeStage: PvpStage.main,
    pendingAttackers: const [],
    revision: 0);
void main() {
  final library = CardLibrary.fromJsonString(
      File('../../data/cards/set02.json').readAsStringSync());
  final pledger = library.card('SF002-004');
  final dummy = library.card('SF002-010');
  GameState board(
          {List<CardInstance> ours = const [],
          List<CardInstance> theirs = const []}) =>
      GameState(
          p1: PlayerState(id: PlayerId.p1, arena: ours),
          p2: PlayerState(id: PlayerId.p2, arena: theirs),
          rngSeed: 17,
          phase: Phase.end,
          activePlayer: PlayerId.p2);
  test(
      'Vow rewards survival exactly once and serialization preserves its spent state',
      () {
    var s = board(ours: [unit(pledger, 1, PlayerId.p1)]);
    s = Game.nextPhase(s);
    expect(s.p1.arena.single.plusCounters, 1);
    final json = jsonDecode(jsonEncode(PvpCodec.encodeSession(PvpSession(
        game: s,
        stage: PvpStage.main,
        ready: const {},
        mulliganUsed: const {},
        priority: PlayerId.p1,
        passCount: 0,
        resumeStage: PvpStage.main,
        pendingAttackers: const [],
        revision: 0)))) as Map<String, dynamic>;
    s = PvpCodec.decodeSession(json, library).game;
    s = Game.nextPhase(s.copyWith(phase: Phase.end, activePlayer: PlayerId.p2));
    expect(s.p1.arena.single.plusCounters, 1);
  });
  test('opponent removal prevents Vow and bounce starts a new Arena stay', () {
    var s = board(ours: [unit(pledger, 1, PlayerId.p1)]);
    final kill = {
      'effects': [
        {
          'op': 'DESTROY',
          'target': {
            'select': 'ALL',
            'owner': 'OPPONENT',
            'filter': {'type': 'UNIT'}
          }
        }
      ]
    };
    s = EffectInterpreter.applyTrigger(s, unit(dummy, 2, PlayerId.p2), kill);
    s = Game.nextPhase(s);
    expect(s.p1.arena, isEmpty);
    expect(s.p1.ruins.single.plusCounters, 0);
    s = Game.nextPhase(board(ours: [unit(pledger, 1, PlayerId.p1)]));
    s = EffectInterpreter.applyTrigger(s, unit(dummy, 2, PlayerId.p2), {
      'effects': [
        {
          'op': 'RETURN_TO_HAND',
          'target': {
            'select': 'ALL',
            'owner': 'OPPONENT',
            'filter': {'type': 'UNIT'}
          }
        }
      ]
    });
    s = s
        .withPlayer(s.p1.copyWith(aetherPool: {Dominion.verdance: 20}))
        .copyWith(phase: Phase.main1);
    s = Game.playUnit(s, PlayerId.p1, 1);
    s = Game.nextPhase(s.copyWith(phase: Phase.end, activePlayer: PlayerId.p2));
    expect(s.p1.arena.single.plusCounters, 2);
  });
  test('Renew heals bounded damage and adds one counter only if damage removed',
      () {
    var s = board(ours: [unit(dummy, 1, PlayerId.p1, damage: 3)]);
    final source = unit(library.card('SF002-015'), 9, PlayerId.p1);
    final block = source.def.effects.single;
    s = EffectInterpreter.applyTrigger(s, source, block,
        chosen: [EffectTarget.unit(1)]);
    expect(s.p1.arena.single.damage, 1);
    expect(s.p1.arena.single.plusCounters, 1);
    s = EffectInterpreter.applyTrigger(s, source, block,
        chosen: [EffectTarget.unit(1)]);
    expect(s.p1.arena.single.damage, 0);
    expect(s.p1.arena.single.plusCounters, 2);
    s = EffectInterpreter.applyTrigger(s, source, block,
        chosen: [EffectTarget.unit(1)]);
    expect(s.p1.arena.single.plusCounters, 2);
  });
  test(
      'Renew cannot affect an enemy, absent target or a player; AI chooses a wounded friend',
      () {
    final healthy = unit(dummy, 1, PlayerId.p1);
    final wounded = unit(dummy, 2, PlayerId.p1, damage: 2);
    final enemy = unit(dummy, 3, PlayerId.p2, damage: 2);
    final s = board(ours: [healthy, wounded], theirs: [enemy]);
    final source = unit(library.card('SF002-015'), 9, PlayerId.p1);
    for (final target in [
      EffectTarget.unit(3),
      EffectTarget.unit(99),
      EffectTarget.player(PlayerId.p1)
    ]) {
      final after = EffectInterpreter.applyTrigger(
          s, source, source.def.effects.single,
          chosen: [target]);
      expect(after.p1.arena[1].damage, 2);
      expect(after.p2.arena.single.damage, 2);
    }
    expect(
        const AiPlayer()
            .chooseTargets(s, PlayerId.p1, source.def)
            .single
            .instanceId,
        2);
    expect(const AiPlayer().requiresUnitTarget(source.def), isTrue);
  });
  test('temporary Renew combat support expires but permanent counters remain',
      () {
    var s = board(ours: [unit(dummy, 1, PlayerId.p1, damage: 2)]);
    final source = unit(library.card('SF002-033'), 9, PlayerId.p1);
    s = EffectInterpreter.applyTrigger(s, source, source.def.effects.single);
    expect(s.p1.arena.single.tempGuard, 2);
    expect(s.p1.arena.single.plusCounters, 1);
    s = Game.nextPhase(s);
    expect(s.p1.arena.single.tempGuard, 0);
    expect(s.p1.arena.single.plusCounters, 1);
  });
  test('expansion tokens survive PvP persistence with their full definition',
      () {
    final source = unit(library.card('SF002-017'), 9, PlayerId.p1);
    final s = EffectInterpreter.applyTrigger(
        board(), source, source.def.effects.single);
    final encoded = jsonDecode(jsonEncode(PvpCodec.encodeSession(session(s))))
        as Map<String, dynamic>;
    final restored = PvpCodec.decodeSession(encoded, library).game;
    expect(restored.p1.arena.length, 2);
    expect(restored.p1.arena.first.def.name, 'Sapling');
    expect(restored.p1.arena.first.def.might, 1);
    expect(restored.nextInstanceId, s.nextInstanceId);
  });
  test('damage removal fires the new cards death payoff exactly once', () {
    final victim = unit(library.card('SF002-046'), 1, PlayerId.p1);
    final source = unit(dummy, 2, PlayerId.p2);
    var s = board(ours: [victim]);
    final block = {
      'effects': [
        {
          'op': 'DEAL_DAMAGE',
          'amount': 3,
          'target': {
            'select': 'ALL',
            'owner': 'OPPONENT',
            'filter': {'type': 'UNIT'}
          }
        }
      ]
    };
    s = EffectInterpreter.applyTrigger(s, source, block);
    expect(s.p2.health, 24);
    expect(s.p1.ruins.single.instanceId, 1);
    s = EffectInterpreter.applyTrigger(s, source, block);
    expect(s.p2.health, 24);
  });
  test('AI simulations fire combat death effects like the app and PvP paths',
      () {
    final s = GameState(
        p1: PlayerState(id: PlayerId.p1, arena: [unit(dummy, 1, PlayerId.p1)]),
        p2: PlayerState(
            id: PlayerId.p2,
            health: 1,
            arena: [unit(library.card('SF002-046'), 2, PlayerId.p2)]),
        rngSeed: 3,
        phase: Phase.main1);
    final after = const AiPlayer().playTurn(s, PlayerId.p1,
        defenderAi: const AiPlayer(tier: AiTier.tactician));
    expect(after.p2.ruins.length, 1);
    expect(after.p1.health, 24);
  });
  test(
      'AI respects temporary Soar and Dread granted by expansion combat tricks',
      () {
    var s = board(ours: [
      unit(dummy, 1, PlayerId.p1).copyWith(tempKeywords: {Keyword.soar})
    ], theirs: [
      unit(library.card('SF002-012'), 2, PlayerId.p2)
    ]);
    final flying = const AiPlayer().chooseBlocks(s, PlayerId.p2, [1]);
    expect(flying.single.blockerIds, isEmpty);
    s = s.withPlayer(s.p1.copyWith(arena: [
      unit(dummy, 1, PlayerId.p1).copyWith(tempKeywords: {Keyword.dread})
    ]));
    final dreaded = const AiPlayer().chooseBlocks(s, PlayerId.p2, [1]);
    expect(dreaded.single.blockerIds, isEmpty);
  });
  test('AI death delivery does not repeat a death caused by an attack trigger',
      () {
    final attacker = CardDef(
        id: 'attack-test',
        name: 'Attack event test',
        dominions: [Dominion.pyre],
        type: CardType.unit,
        might: 2,
        guard: 4,
        effects: [
          {
            'trigger': 'ON_ATTACK',
            'effects': [
              {
                'op': 'DESTROY',
                'target': {
                  'select': 'ALL',
                  'owner': 'OPPONENT',
                  'filter': {'type': 'UNIT'}
                }
              }
            ]
          }
        ]);
    final s = GameState(
        p1: PlayerState(
            id: PlayerId.p1, arena: [unit(attacker, 1, PlayerId.p1)]),
        p2: PlayerState(
            id: PlayerId.p2,
            arena: [unit(library.card('SF002-046'), 2, PlayerId.p2)]),
        rngSeed: 4,
        phase: Phase.main1);
    final after =
        const AiPlayer().playTurn(s, PlayerId.p1, defenderAi: const AiPlayer());
    expect(after.p2.ruins.length, 1);
    expect(after.p1.health, 24);
  });
  test(
      'every catalog effect resolves through actual enter/cast/vow/death paths',
      () {
    const supported = {
      'DEAL_DAMAGE',
      'HEAL',
      'DRAW',
      'DISCARD',
      'ADD_COUNTER',
      'BUFF',
      'DESTROY',
      'RETURN_TO_HAND',
      'GAIN_AETHER',
      'GRANT_KEYWORD',
      'COUNTER_SPELL',
      'SEARCH_DECK',
      'CREATE_TOKEN',
      'RENEW'
    };
    for (final def in library.byId.values) {
      var s = board(
          ours: [unit(dummy, 1, PlayerId.p1, damage: 1)],
          theirs: [unit(dummy, 2, PlayerId.p2, damage: 1)]);
      s = s.copyWith(
          phase: Phase.main1, activePlayer: PlayerId.p1, nextInstanceId: 200);
      s = s.withPlayer(s.p1.copyWith(hand: [
        unit(def, 9, PlayerId.p1)
      ], deck: [
        for (var i = 0; i < 20; i++) unit(dummy, 100 + i, PlayerId.p1)
      ], aetherPool: {
        for (final d in Dominion.values) d: 30
      }));
      for (final b in def.effects) {
        expect({
          'ON_ENTER_ARENA',
          'ON_CAST',
          'ON_VOW',
          'ON_DEATH'
        }, contains(b['trigger']), reason: def.id);
        for (final raw in b['effects'] as List) {
          expect(supported, contains((raw as Map)['op']), reason: def.id);
        }
      }
      final targets = const AiPlayer().chooseTargets(s, PlayerId.p1, def);
      if (def.type == CardType.unit) {
        s = Game.playUnit(s, PlayerId.p1, 9, chosen: targets);
        s = Game.nextPhase(
            s.copyWith(phase: Phase.end, activePlayer: PlayerId.p2));
        s = EffectInterpreter.fireDeathTriggers(s, [unit(def, 9, PlayerId.p1)]);
      } else if (def.type == CardType.rite || def.type == CardType.ritual) {
        s = Chain.resolveAll(Chain.cast(s, PlayerId.p1, 9, targets: targets));
      } else {
        s = Game.playWellspring(s, PlayerId.p1, 9);
      }
      expect(s.p1.health, greaterThan(0), reason: def.id);
      final encoded = jsonDecode(jsonEncode(PvpCodec.encodeSession(session(s))))
          as Map<String, dynamic>;
      expect(() => PvpCodec.decodeSession(encoded, library), returnsNormally,
          reason: def.id);
    }
  });
}
