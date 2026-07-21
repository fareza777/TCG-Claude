import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef unitDef(String id, {int might = 2, int guard = 2}) => CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      might: might,
      guard: guard,
    );

CardInstance inst(int id, CardDef def, PlayerId owner) =>
    CardInstance(instanceId: id, def: def, owner: owner);

GameState baseState({
  List<CardInstance> p1Arena = const [],
  List<CardInstance> p2Arena = const [],
  List<CardInstance> p1Deck = const [],
  List<CardInstance> p2Hand = const [],
}) =>
    GameState(
      p1: PlayerState(id: PlayerId.p1, arena: p1Arena, deck: p1Deck),
      p2: PlayerState(id: PlayerId.p2, arena: p2Arena, hand: p2Hand),
      rngSeed: 0,
    );

void main() {
  test('Grovewarden Stag: +1/+1 counter on each other friendly unit', () {
    final stag = inst(1, unitDef('Stag'), PlayerId.p1);
    final ally = inst(2, unitDef('Ally'), PlayerId.p1);
    final enemy = inst(3, unitDef('Enemy'), PlayerId.p2);
    final s = baseState(p1Arena: [stag, ally], p2Arena: [enemy]);

    final trigger = {
      'trigger': 'ON_ENTER_ARENA',
      'effects': [
        {
          'op': 'ADD_COUNTER',
          'counter': 'PLUS1',
          'amount': 1,
          'target': {
            'select': 'ALL',
            'zone': 'ARENA',
            'owner': 'SELF',
            'filter': {'type': 'UNIT', 'excludeSelf': true},
          },
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, stag, trigger);
    expect(after.p1.arena[0].plusCounters, 0, reason: 'stag excluded');
    expect(after.p1.arena[1].plusCounters, 1);
    expect(after.p1.arena[1].might, 3);
    expect(after.p2.arena[0].plusCounters, 0, reason: 'enemy untouched');
  });

  test('Cinder Bolt: 2 damage to chosen unit kills a 2-guard', () {
    final source = inst(1, unitDef('Bolt'), PlayerId.p1);
    final target = inst(2, unitDef('Chump'), PlayerId.p2);
    final s = baseState(p1Arena: [source], p2Arena: [target]);

    final trigger = {
      'effects': [
        {
          'op': 'DEAL_DAMAGE',
          'amount': 2,
          'target': {'select': 'CHOOSE'},
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger,
        chosen: const [EffectTarget.unit(2)]);
    expect(after.p2.arena, isEmpty);
    expect(after.p2.ruins.length, 1);
  });

  test('DEAL_DAMAGE to player can win the game', () {
    final source = inst(1, unitDef('Nuke'), PlayerId.p1);
    var s = baseState(p1Arena: [source]);
    s = s.withPlayer(s.p2.copyWith(health: 2));

    final trigger = {
      'effects': [
        {
          'op': 'DEAL_DAMAGE',
          'amount': 2,
          'target': {'select': 'CHOOSE'},
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger,
        chosen: const [EffectTarget.player(PlayerId.p2)]);
    expect(after.winner, PlayerId.p1);
  });

  test('HEAL SELF_PLAYER and DRAW', () {
    final source = inst(1, unitDef('Cleric'), PlayerId.p1);
    final deckCard = inst(9, unitDef('Top'), PlayerId.p1);
    var s = baseState(p1Arena: [source], p1Deck: [deckCard]);
    s = s.withPlayer(s.p1.copyWith(health: 20));

    final trigger = {
      'effects': [
        {
          'op': 'HEAL',
          'amount': 2,
          'target': {'select': 'SELF_PLAYER'},
        },
        {'op': 'DRAW', 'amount': 1},
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger);
    expect(after.p1.health, 22);
    expect(after.p1.hand.length, 1);
    expect(after.p1.deck, isEmpty);
  });

  test('RETURN_TO_HAND resets damage and fatigue', () {
    final source = inst(1, unitDef('Wyrm'), PlayerId.p1);
    final target = inst(2, unitDef('Bounced'), PlayerId.p2)
        .copyWith(damage: 1, exerted: true);
    final s = baseState(p1Arena: [source], p2Arena: [target]);

    final trigger = {
      'effects': [
        {
          'op': 'RETURN_TO_HAND',
          'target': {'select': 'CHOOSE'},
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger,
        chosen: const [EffectTarget.unit(2)]);
    expect(after.p2.arena, isEmpty);
    expect(after.p2.hand.length, 1);
    expect(after.p2.hand.first.damage, 0);
    expect(after.p2.hand.first.exerted, isFalse);
  });

  test('DISCARD from opponent hand goes to ruins', () {
    final source = inst(1, unitDef('Reaper'), PlayerId.p1);
    final held = inst(2, unitDef('Held'), PlayerId.p2);
    final s = baseState(p1Arena: [source], p2Hand: [held]);

    final trigger = {
      'effects': [
        {
          'op': 'DISCARD',
          'amount': 1,
          'target': {'select': 'OPPONENT_PLAYER'},
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger);
    expect(after.p2.hand, isEmpty);
    expect(after.p2.ruins.length, 1);
  });

  test('BUFF grants temporary might/guard that survives combat math', () {
    final source = inst(1, unitDef('Trick'), PlayerId.p1);
    final target = inst(2, unitDef('Ally', might: 2, guard: 2), PlayerId.p1);
    final s = baseState(p1Arena: [source, target]);
    final trigger = {
      'effects': [
        {
          'op': 'BUFF',
          'might': 3,
          'guard': 1,
          'target': {'select': 'CHOOSE'},
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger,
        chosen: const [EffectTarget.unit(2)]);
    final buffed = after.p1.arena.firstWhere((c) => c.instanceId == 2);
    expect(buffed.might, 5, reason: '2 + 3 temp');
    expect(buffed.guard, 3, reason: '2 + 1 temp');
  });

  test('CREATE_TOKEN spawns units in the caster arena', () {
    final source = inst(1, unitDef('Summoner'), PlayerId.p1);
    final s = baseState(p1Arena: [source]);
    final trigger = {
      'effects': [
        {
          'op': 'CREATE_TOKEN',
          'amount': 2,
          'token': {
            'name': 'Wolf',
            'dominion': ['verdance'],
            'might': 2,
            'guard': 2,
            'keywords': ['rush'],
          },
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger);
    final tokens =
        after.p1.arena.where((c) => c.def.name == 'Wolf').toList();
    expect(tokens.length, 2);
    expect(tokens.first.def.keywords.contains(Keyword.rush), isTrue);
  });

  test('SEARCH_DECK pulls the first matching card to hand', () {
    final source = inst(1, unitDef('Seeker'), PlayerId.p1);
    final unitCard = inst(8, unitDef('DeckUnit'), PlayerId.p1);
    final well = CardInstance(
        instanceId: 9,
        def: const CardDef(
            id: 'W',
            name: 'Well',
            dominions: [Dominion.verdance],
            type: CardType.wellspring),
        owner: PlayerId.p1);
    final s = baseState(p1Arena: [source], p1Deck: [unitCard, well]);
    final trigger = {
      'effects': [
        {
          'op': 'SEARCH_DECK',
          'filter': {'type': 'WELLSPRING'},
          'destination': 'HAND',
        }
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger);
    expect(after.p1.hand.any((c) => c.def.type == CardType.wellspring), isTrue);
    expect(after.p1.deck.length, 1);
  });

  test('ON_DEATH trigger fires when a unit dies', () {
    const deathGain = CardDef(
      id: 'MARTYR',
      name: 'Martyr',
      dominions: [Dominion.gloom],
      type: CardType.unit,
      might: 2,
      guard: 2,
      effects: [
        {
          'trigger': 'ON_DEATH',
          'effects': [
            {'op': 'GAIN_AETHER', 'amount': 1}
          ],
        }
      ],
    );
    final dying = inst(1, deathGain, PlayerId.p1);
    final s = baseState(p1Arena: []);
    final after = EffectInterpreter.fireDeathTriggers(s, [dying]);
    expect(after.p1.aetherPool[Dominion.neutral], 1);
  });

  test('GAIN_AETHER adds to pool', () {
    final source = inst(1, unitDef('Sproutling'), PlayerId.p1);
    final s = baseState(p1Arena: [source]);
    final trigger = {
      'effects': [
        {'op': 'GAIN_AETHER', 'amount': 1},
      ],
    };
    final after = EffectInterpreter.applyTrigger(s, source, trigger);
    expect(after.p1.aetherPool[Dominion.neutral], 1);
  });
}
