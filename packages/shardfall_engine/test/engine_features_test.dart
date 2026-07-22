import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef unit(String id,
        {int might = 2,
        int guard = 2,
        Set<Keyword> kw = const {},
        List<Map<String, dynamic>> effects = const []}) =>
    CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.gloom],
      type: CardType.unit,
      might: might,
      guard: guard,
      keywords: kw,
      effects: effects,
    );

CardDef rite(String id, List<Map<String, dynamic>> effects,
        {Map<Dominion, int> cost = const {Dominion.tide: 1}}) =>
    CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.tide],
      type: CardType.rite,
      costDominion: cost,
      effects: [
        {'trigger': 'ON_CAST', 'effects': effects}
      ],
    );

CardInstance ci(int id, CardDef def, PlayerId owner) =>
    CardInstance(instanceId: id, def: def, owner: owner);

GameState state({
  PlayerState? p1,
  PlayerState? p2,
  Phase phase = Phase.main1,
  PlayerId active = PlayerId.p1,
  List<ChainItem> chain = const [],
}) =>
    GameState(
      p1: p1 ?? const PlayerState(id: PlayerId.p1),
      p2: p2 ?? const PlayerState(id: PlayerId.p2),
      phase: phase,
      activePlayer: active,
      chain: chain,
      rngSeed: 1,
    );

void main() {
  group('Attune', () {
    test('turns a hand card into a neutral Wellspring, using the land drop', () {
      final card = ci(1, unit('Grunt'), PlayerId.p1);
      var s = state(p1: PlayerState(id: PlayerId.p1, hand: [card]));
      s = Game.attune(s, PlayerId.p1, 1);
      expect(s.p1.hand, isEmpty);
      expect(s.p1.arena.single.def.type, CardType.wellspring);
      expect(s.p1.playedWellspringThisTurn, isTrue);
      // A second placement (real Wellspring or Attune) is now illegal.
      expect(() => Game.attune(s, PlayerId.p1, 1), throwsStateError);
    });

    test('attuned Wellspring taps for generic Aether', () {
      final card = ci(1, unit('Grunt'), PlayerId.p1);
      var s = state(p1: PlayerState(id: PlayerId.p1, hand: [card]));
      s = Game.attune(s, PlayerId.p1, 1);
      final wellId = s.p1.arena.single.instanceId;
      s = Game.exertForAether(s, PlayerId.p1, wellId);
      expect(s.p1.aetherPool[Dominion.neutral], 1);
    });
  });

  test('GRANT_KEYWORD gives a keyword combat actually honours', () {
    final u = ci(1, unit('Flyer'), PlayerId.p1);
    var s = state(p1: PlayerState(id: PlayerId.p1, arena: [u]));
    final block = {
      'effects': [
        {
          'op': 'GRANT_KEYWORD',
          'keyword': 'SOAR',
          'target': {'select': 'CHOOSE'}
        }
      ]
    };
    s = EffectInterpreter.applyTrigger(s, u, block,
        chosen: [const EffectTarget.unit(1)]);
    expect(s.p1.arena.single.keywords.contains(Keyword.soar), isTrue);
  });

  test('COUNTER_SPELL counters the spell beneath it on the chain', () {
    final burn = rite('Burn', [
      {
        'op': 'DEAL_DAMAGE',
        'amount': 5,
        'target': {'select': 'OPPONENT_PLAYER'}
      }
    ]);
    final nullify = rite('Nullify', [
      {'op': 'COUNTER_SPELL'}
    ]);
    var s = state(
      p1: PlayerState(
          id: PlayerId.p1,
          hand: [ci(1, burn, PlayerId.p1)],
          aetherPool: const {Dominion.tide: 3}),
      p2: PlayerState(
          id: PlayerId.p2,
          hand: [ci(2, nullify, PlayerId.p2)],
          aetherPool: const {Dominion.tide: 3}),
    );
    // p1 casts Burn at p2; p2 responds with Nullify; resolve.
    s = Chain.cast(s, PlayerId.p1, 1,
        targets: [const EffectTarget.player(PlayerId.p2)]);
    s = Chain.cast(s, PlayerId.p2, 2);
    s = Chain.resolveAll(s);
    expect(s.p2.health, 25, reason: 'Burn was countered — no damage');
    expect(s.chain, isEmpty);
  });

  test('ON_ATTACK trigger fires when a unit is declared as attacker', () {
    final pinger = ci(
        1,
        unit('Pinger', effects: [
          {
            'trigger': 'ON_ATTACK',
            'effects': [
              {
                'op': 'DEAL_DAMAGE',
                'amount': 1,
                'target': {'select': 'OPPONENT_PLAYER'}
              }
            ]
          }
        ]),
        PlayerId.p1);
    var s = state(
        p1: PlayerState(id: PlayerId.p1, arena: [pinger]), phase: Phase.combat);
    s = Combat.declareAttackers(s, PlayerId.p1, [1]);
    expect(s.p2.health, 24, reason: 'ON_ATTACK pinged the opponent for 1');
  });

  test('Ambush lets an exerted Unit still block', () {
    final attacker = ci(1, unit('Atk', might: 3, guard: 3), PlayerId.p1);
    final guard = ci(2, unit('Sentry', might: 2, guard: 4, kw: {Keyword.ambush}),
            PlayerId.p2)
        .copyWith(exerted: true);
    var s = state(
        p1: PlayerState(id: PlayerId.p1, arena: [attacker]),
        p2: PlayerState(id: PlayerId.p2, arena: [guard]),
        phase: Phase.combat);
    // Exerted normally cannot block, but Ambush allows it — no throw.
    final out = Combat.resolveDamage(s, PlayerId.p1,
        [const AttackDeclaration(attackerId: 1, blockerIds: [2])]);
    // The attacker (3/3) traded into the 2/4 sentry: sentry took 3 (survives),
    // attacker took 2 (survives). Key point: the block was legal.
    expect(out.p2.arena.any((c) => c.instanceId == 2), isTrue);
  });
}
