import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef _unit(String id, {int cost = 1, int might = 2, int guard = 2}) =>
    CardDef(
      id: id,
      name: 'Unit $id',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      costGeneric: cost,
      might: might,
      guard: guard,
      keywords: const {Keyword.alert},
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
        {'effects': <Object>[]},
      ],
    );

List<CardDef> _deck(String prefix) => [
      for (var i = 0; i < 16; i++) _wellspring('$prefix-ws-$i'),
      for (var i = 0; i < 24; i++) _unit('$prefix-unit-$i'),
    ];

/// A drawable library so a turn change does not deck-out the fixture.
List<CardInstance> _deckInstances(String prefix, PlayerId owner) => [
      for (var i = 0; i < 20; i++)
        CardInstance(
          instanceId: 900 + i + (owner == PlayerId.p1 ? 0 : 100),
          def: _unit('$prefix-lib-$i'),
          owner: owner,
        ),
    ];

PvpCommand _command(
  PvpSession session,
  PvpCommandType type, {
  String key = 'command',
  Map<String, dynamic> payload = const {},
}) =>
    PvpCommand(
      type: type,
      idempotencyKey: key,
      revision: session.revision,
      payload: payload,
    );

PvpSession _mainSession({
  List<CardInstance> p1Hand = const [],
  List<CardInstance> p1Arena = const [],
  List<CardInstance> p2Hand = const [],
  List<CardInstance> p2Arena = const [],
  Phase phase = Phase.main1,
  PlayerId activePlayer = PlayerId.p1,
}) {
  return PvpSession(
    game: GameState(
      p1: PlayerState(
        id: PlayerId.p1,
        hand: p1Hand,
        arena: p1Arena,
        deck: _deckInstances('p1', PlayerId.p1),
      ),
      p2: PlayerState(
        id: PlayerId.p2,
        hand: p2Hand,
        arena: p2Arena,
        deck: _deckInstances('p2', PlayerId.p2),
      ),
      activePlayer: activePlayer,
      phase: phase,
      rngSeed: 11,
      firstPlayer: PlayerId.p1,
    ),
    stage: PvpStage.main,
    ready: const {PlayerId.p1: true, PlayerId.p2: true},
    mulliganUsed: const {PlayerId.p1: true, PlayerId.p2: true},
    priority: activePlayer,
    passCount: 0,
    resumeStage: PvpStage.main,
    pendingAttackers: const [],
    revision: 0,
  );
}

void main() {
  test('both ready commands open the mulligan window, then main play', () {
    var session = PvpEngine.create(
      deckP1: _deck('p1'),
      deckP2: _deck('p2'),
      seed: 42,
    );

    var result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.ready, key: 'p1-ready'),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    result = PvpEngine.apply(
      session,
      PlayerId.p2,
      _command(session, PvpCommandType.ready, key: 'p2-ready'),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.stage, PvpStage.mulligan);
    expect(session.ready[PlayerId.p1], isFalse);
    expect(session.ready[PlayerId.p2], isFalse);

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.redraw, key: 'p1-redraw'),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.usedMulligan(PlayerId.p1), isTrue);

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.ready, key: 'p1-confirm'),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.isReady(PlayerId.p1), isTrue);

    result = PvpEngine.apply(
      session,
      PlayerId.p2,
      _command(session, PvpCommandType.ready, key: 'p2-confirm'),
    );
    expect(result.accepted, isTrue);
    expect(result.session.stage, PvpStage.main);
    expect(result.session.game.phase, Phase.main1);
  });

  test('advancing past Main 2 lands on the next player\'s Main 1', () {
    // Main 2 -> end -> (turn change) refresh -> draw -> Main 1. Stopping on any
    // of those bookkeeping phases still reported PvpStage.main, so the client
    // offered card plays that the rules rejected as "not legal in this phase".
    final session = _mainSession(phase: Phase.main2);

    final result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.nextPhase, key: 'advance'),
    );

    expect(result.accepted, isTrue);
    expect(result.session.game.phase, Phase.main1);
    expect(result.session.game.activePlayer, PlayerId.p2);
    expect(result.session.stage, PvpStage.main);
  });

  test('a main action is legal on every phase reported as the main stage', () {
    // The contract the freeze violated: if the stage says main, the rules must
    // accept a main action.
    for (final phase in [Phase.main1, Phase.main2]) {
      final session = _mainSession(phase: phase);
      expect(session.stage, PvpStage.main, reason: 'setup for $phase');

      final advanced = PvpEngine.apply(
        session,
        PlayerId.p1,
        _command(session, PvpCommandType.nextPhase, key: 'advance-$phase'),
      );
      expect(advanced.accepted, isTrue);

      final next = advanced.session;
      if (next.stage == PvpStage.main) {
        expect(
          next.game.phase == Phase.main1 || next.game.phase == Phase.main2,
          isTrue,
          reason: 'stage main must mean a main phase, got ${next.game.phase}',
        );
      }
    }
  });

  test('a heartbeat publishes nothing and changes nothing', () {
    // Heartbeats were 38% of all commands in real matches. Every published
    // event lands in pvp_events, which Realtime pushes to both clients, each
    // of which then refetches the whole projection. Presence must not cost
    // that.
    final session = _mainSession();

    final result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.heartbeat, key: 'beat'),
    );

    expect(result.accepted, isTrue);
    expect(result.events, isEmpty, reason: 'no Realtime fan-out for presence');
    expect(result.session.revision, session.revision);
  });

  test('a real move still publishes its events', () {
    final session = _mainSession();

    final result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.nextPhase, key: 'advance'),
    );

    expect(result.events, isNotEmpty);
    expect(result.session.revision, session.revision + 1);
  });

  test('wrong actor and stale revision are rejected without changing state',
      () {
    final session = _mainSession();

    final wrongActor = PvpEngine.apply(
      session,
      PlayerId.p2,
      _command(session, PvpCommandType.nextPhase, key: 'wrong-actor'),
    );
    expect(wrongActor.accepted, isFalse);
    expect(wrongActor.error?.code, 'not_your_turn');
    expect(wrongActor.session.revision, 0);

    final stale = PvpEngine.apply(
      session,
      PlayerId.p1,
      const PvpCommand(
        type: PvpCommandType.nextPhase,
        idempotencyKey: 'stale',
        revision: 7,
      ),
    );
    expect(stale.accepted, isFalse);
    expect(stale.error?.code, 'stale_revision');
    expect(stale.session.game.phase, Phase.main1);
  });

  test('resources and unit actions use the existing pure rules', () {
    final ws = CardInstance(
      instanceId: 1,
      def: _wellspring('ws'),
      owner: PlayerId.p1,
    );
    final unit = CardInstance(
      instanceId: 2,
      def: _unit('unit'),
      owner: PlayerId.p1,
    );
    var session = _mainSession(p1Hand: [ws, unit]);

    var result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.playWellspring,
        key: 'play-ws',
        payload: {'instanceId': 1},
      ),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.exertForAether,
        key: 'exert-ws',
        payload: {'instanceId': 1},
      ),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.playUnit,
        key: 'play-unit',
        payload: {'instanceId': 2},
      ),
    );
    expect(result.accepted, isTrue);
    expect(result.session.game.p1.hand, isEmpty);
    expect(result.session.game.p1.arena.map((c) => c.instanceId),
        containsAll([1, 2]));
    expect(
        result.session.game.p1.aetherPool.values.fold(0, (a, b) => a + b), 0);
  });

  test('Chain priority resolves a cast only after two passes', () {
    final rite = CardInstance(
      instanceId: 7,
      def: _rite('rite'),
      owner: PlayerId.p1,
    );
    var session = _mainSession(p1Hand: [rite]);

    var result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.cast,
        key: 'cast',
        payload: {'instanceId': 7, 'targets': const []},
      ),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.stage, PvpStage.chainPriority);
    expect(session.priority, PlayerId.p2);
    expect(session.game.chain, hasLength(1));

    result = PvpEngine.apply(
      session,
      PlayerId.p2,
      _command(session, PvpCommandType.passPriority, key: 'pass-p2'),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.passCount, 1);
    expect(session.priority, PlayerId.p1);
    expect(session.game.chain, hasLength(1));

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.passPriority, key: 'pass-p1'),
    );
    expect(result.accepted, isTrue);
    expect(result.session.stage, PvpStage.main);
    expect(result.session.game.chain, isEmpty);
    expect(result.session.game.p1.ruins.single.instanceId, 7);
  });

  test('attack and block commands resolve combat then enter Main 2', () {
    final attacker = CardInstance(
      instanceId: 10,
      def: _unit('attacker', might: 3),
      owner: PlayerId.p1,
    );
    final blocker = CardInstance(
      instanceId: 20,
      def: _unit('blocker', might: 1, guard: 3),
      owner: PlayerId.p2,
    );
    var session = _mainSession(
      p1Arena: [attacker],
      p2Arena: [blocker],
      phase: Phase.combat,
    ).copyWith(stage: PvpStage.attackDeclaration);

    var result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.declareAttackers,
        key: 'attack',
        payload: {
          'attackerIds': [10]
        },
      ),
    );
    expect(result.accepted, isTrue);
    session = result.session;
    expect(session.stage, PvpStage.blockDeclaration);

    result = PvpEngine.apply(
      session,
      PlayerId.p2,
      _command(
        session,
        PvpCommandType.declareBlocks,
        key: 'blocks',
        payload: {
          'blocks': [
            {
              'attackerId': 10,
              'blockerIds': [20]
            },
          ],
        },
      ),
    );
    expect(result.accepted, isTrue);
    expect(result.session.stage, PvpStage.main);
    expect(result.session.game.phase, Phase.main2);
    expect(result.session.game.p2.health, 25);
    expect(result.session.game.p1.arena.single.damage, 1);
  });

  test('next phase can walk refresh and draw before the opponent main phase',
      () {
    var session = _mainSession();

    var result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(session, PvpCommandType.nextPhase, key: 'to-combat'),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    result = PvpEngine.apply(
      session,
      PlayerId.p1,
      _command(
        session,
        PvpCommandType.declareAttackers,
        key: 'no-attack',
        payload: {'attackerIds': const []},
      ),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    // One press. refresh, draw and end hold no decision, so the engine runs
    // them through instead of parking the player on a phase where the rules
    // reject every action.
    result = PvpEngine.apply(
      session,
      session.game.activePlayer,
      _command(session, PvpCommandType.nextPhase, key: 'to-p2-main'),
    );
    expect(result.accepted, isTrue);
    session = result.session;

    expect(session.game.activePlayer, PlayerId.p2);
    expect(session.game.phase, Phase.main1);
  });

  test('concede finishes the match and deterministic replay stays identical',
      () {
    final first = _mainSession();
    final second = _mainSession();
    final command = _command(first, PvpCommandType.concede, key: 'concede');

    final a = PvpEngine.apply(first, PlayerId.p1, command);
    final b = PvpEngine.apply(second, PlayerId.p1, command);

    expect(a.accepted, isTrue);
    expect(a.session.stage, PvpStage.finished);
    expect(a.session.game.winner, PlayerId.p2);
    expect(
        PvpCodec.encodeSession(a.session), PvpCodec.encodeSession(b.session));
  });
}
