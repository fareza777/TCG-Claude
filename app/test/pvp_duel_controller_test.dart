import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/pvp/pvp_controller.dart';
import 'package:shardfall/pvp/pvp_duel_controller.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall/pvp/pvp_service.dart';

const _library = CardLibrary(byId: {}, starterDecks: {});

/// A unit that costs Aether, so paying for it is not a no-op.
const _costedLibrary = CardLibrary(
  byId: {
    'unit-1': CardDef(
      id: 'unit-1',
      name: 'Costed Unit',
      dominions: [Dominion.verdance],
      type: CardType.unit,
      costGeneric: 1,
      might: 2,
      guard: 2,
    ),
    'ws-1': CardDef(
      id: 'ws-1',
      name: 'Wellspring',
      dominions: [Dominion.verdance],
      type: CardType.wellspring,
    ),
  },
  starterDecks: {},
);

Map<String, dynamic> _cardView(
  int instanceId, {
  required String cardId,
  required String type,
}) =>
    {
      'instanceId': instanceId,
      'cardId': cardId,
      'name': 'Card $instanceId',
      'type': type,
      'subtype': '',
      'dominions': const ['verdance'],
      'might': 2,
      'guard': 2,
      'exerted': false,
      'damage': 0,
      'plusCounters': 0,
      'summonedThisTurn': false,
    };

Map<String, dynamic> _player(String id, {int health = 25}) => {
      'id': id,
      'health': health,
      'hand': const [],
      'handCount': 0,
      'deckCount': 30,
      'arena': const [],
      'ruinsCount': 0,
      'voidCount': 0,
      'aetherPool': const {},
      'playedWellspringThisTurn': false,
      'usedAttuneThisTurn': false,
    };

PvpProjection _projection({
  required String viewer,
  String activePlayer = 'p1',
  String stage = 'main',
  String? winner,
  String? priority,
}) =>
    PvpProjection.fromJson({
      'version': 1,
      'activePlayer': activePlayer,
      'phase': 'main1',
      'turnNumber': 1,
      'winner': winner,
      'chainCount': 0,
      'stage': stage,
      'priority': priority ?? activePlayer,
      'pendingAttackers': const [],
      'revision': 1,
      'players': {
        'p1': {..._player('p1', health: 11), 'viewer': viewer},
        'p2': {..._player('p2', health: 22), 'viewer': viewer},
      },
    });

class _Gateway implements PvpGateway {
  _Gateway(this.projection);

  final PvpProjection projection;
  final commands = <PvpCommand>[];

  @override
  Future<String?> findActiveMatch() async => 'match-1';

  /// Events the match has already emitted; drained once, like the real table.
  List<PvpMatchEvent> events = const [];

  @override
  Future<List<PvpMatchEvent>> eventsSince(String matchId, int afterSeq) async {
    final pending = [for (final e in events) if (e.seq > afterSeq) e];
    return pending;
  }

  @override
  Future<PvpProjection> reconnect(String matchId) async => projection;

  /// Projections handed back in order, so a multi-step action can be followed.
  List<PvpProjection> replies = const [];
  int _reply = 0;

  @override
  Future<PvpCommandResponse> sendCommand(
    String matchId,
    PvpCommand command,
  ) async {
    commands.add(command);
    final next = _reply < replies.length ? replies[_reply++] : projection;
    return PvpCommandResponse(
      accepted: true,
      duplicate: false,
      status: 'active',
      revision: command.revision + 1,
      projection: next,
    );
  }

  @override
  Stream<PvpProjection> watchMatch(
    String id,
    String userId, {
    int Function()? appliedRevision,
  }) =>
      const Stream.empty();

  @override
  Stream<String> watchQueue(String userId) => const Stream.empty();

  @override
  Future<PvpQueueResult> joinQueue(List<String> deck) async =>
      const PvpQueueResult(status: 'queued');

  @override
  Future<void> leaveQueue() async {}

  @override
  void dispose() {}
}

class _SilentGateway extends _Gateway {
  _SilentGateway(super.projection);

  @override
  Future<PvpCommandResponse> sendCommand(String matchId, PvpCommand command) {
    commands.add(command);
    return Completer<PvpCommandResponse>().future; // never answers
  }
}

Future<PvpDuelController> _attach(PvpProjection projection) async {
  final gateway = _Gateway(projection);
  final pvp = PvpController(gateway: gateway, userId: 'user-1');
  await pvp.resumeActiveMatch();
  return PvpDuelController(pvp: pvp, library: _library, deck: const []);
}

void main() {
  test('a player seated as p2 still sees themselves as the local player',
      () async {
    // The duel screen reads `me` as p1. Without the remap, a p2 player would
    // watch their opponent's health bar as if it were their own.
    final duel = await _attach(_projection(viewer: 'p2'));

    expect(duel.me.health, 22, reason: 'p2 is the viewer here');
    expect(duel.foe.health, 11);
    duel.dispose();
  });

  test('the board is drawn straight for a player seated as p1', () async {
    final duel = await _attach(_projection(viewer: 'p1'));

    expect(duel.me.health, 11);
    expect(duel.foe.health, 22);
    duel.dispose();
  });

  test('input is enabled only on this player\'s decision', () async {
    final mine = await _attach(_projection(viewer: 'p1', activePlayer: 'p1'));
    expect(mine.ui, DuelUiState.playerMain);
    expect(mine.busy, isFalse);
    mine.dispose();

    final theirs = await _attach(_projection(viewer: 'p1', activePlayer: 'p2'));
    expect(theirs.ui, DuelUiState.enemyTurn);
    expect(theirs.busy, isTrue, reason: 'the screen must not accept taps');
    theirs.dispose();
  });

  test('the defender is the one who assigns blocks', () async {
    // p2 attacks, so the viewer p1 is defending.
    final defender = await _attach(
      _projection(viewer: 'p1', activePlayer: 'p2', stage: 'blockDeclaration'),
    );
    expect(defender.ui, DuelUiState.playerBlocking);
    expect(defender.busy, isFalse);
    defender.dispose();

    final attacker = await _attach(
      _projection(viewer: 'p1', activePlayer: 'p1', stage: 'blockDeclaration'),
    );
    expect(attacker.ui, DuelUiState.enemyTurn);
    attacker.dispose();
  });

  test('holding priority opens the response window', () async {
    final duel = await _attach(
      _projection(
        viewer: 'p1',
        activePlayer: 'p2',
        stage: 'chainPriority',
        priority: 'p1',
      ),
    );

    expect(duel.ui, DuelUiState.playerResponse);
    expect(duel.busy, isFalse);
    duel.dispose();
  });

  test('a finished match reports the winner from the viewer\'s side',
      () async {
    final won = await _attach(
      _projection(viewer: 'p2', stage: 'finished', winner: 'p2'),
    );
    expect(won.ui, DuelUiState.gameOver);
    expect(won.isGameOver, isTrue);
    expect(won.playerWon, isTrue, reason: 'the viewer p2 won');
    won.dispose();

    final lost = await _attach(
      _projection(viewer: 'p2', stage: 'finished', winner: 'p1'),
    );
    expect(lost.playerWon, isFalse);
    lost.dispose();
  });

  test('the mulligan window is offered before play starts', () async {
    final duel = await _attach(
      _projection(viewer: 'p1', stage: 'waitingForReady'),
    );

    expect(duel.awaitingMulligan, isTrue);
    duel.dispose();
  });

  test('server events become the cues the battle screen animates', () async {
    // Without this the board would still be correct but lifeless: no lunge on
    // an attack, no sound when a card lands.
    final gateway = _Gateway(_projection(viewer: 'p1'))
      ..events = const [
        PvpMatchEvent(seq: 1, type: 'card_played', payload: {'instanceId': 7}),
        PvpMatchEvent(
          seq: 2,
          type: 'attack_declared',
          payload: {'attackerIds': [3, 4]},
        ),
      ];
    final pvp = PvpController(gateway: gateway, userId: 'user-1');
    await pvp.resumeActiveMatch();
    final duel = PvpDuelController(
      pvp: pvp,
      library: _library,
      deck: const [],
    );
    // The events are fetched off the projection apply, so let it settle.
    await Future<void>.delayed(Duration.zero);
    duel.dispose();

    final kinds = duel.pendingEvents.map((e) => e.kind).toList();
    expect(kinds, containsAll(<String>['play', 'attack']));
    expect(duel.history, isNotEmpty,
        reason: 'the battle log panel must not sit empty in PvP');
    expect(
      duel.pendingEvents
          .where((e) => e.kind == 'attack')
          .map((e) => e.instanceId),
      containsAll(<int>[3, 4]),
    );
  });

  test('playing a card costs exactly one round trip', () async {
    // The client used to raise Aether itself, sending one exertForAether per
    // Wellspring before the play. A two-cost card was therefore three network
    // round trips, and live testing showed that as visible lag. The server
    // funds the play now, so one tap must send one command.
    final unit = _cardView(5, cardId: 'unit-1', type: 'unit');
    final well = _cardView(9, cardId: 'ws-1', type: 'wellspring');
    final projection = PvpProjection.fromJson({
      'version': 1,
      'activePlayer': 'p1',
      'phase': 'main1',
      'turnNumber': 1,
      'winner': null,
      'chainCount': 0,
      'stage': 'main',
      'priority': 'p1',
      'pendingAttackers': const [],
      'revision': 1,
      'players': {
        'p1': {
          ..._player('p1'),
          'viewer': 'p1',
          'hand': [unit],
          'handCount': 1,
          'arena': [well],
        },
        'p2': {..._player('p2'), 'viewer': 'p1'},
      },
    });

    final gateway = _Gateway(projection);
    final pvp = PvpController(gateway: gateway, userId: 'user-1');
    await pvp.resumeActiveMatch();
    final duel = PvpDuelController(
      pvp: pvp,
      library: _costedLibrary,
      deck: const [],
    );

    duel.playHandCard(5);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    duel.dispose();

    final sent = gateway.commands.map((c) => c.type).toList();
    expect(sent, [PvpCommandType.playUnit],
        reason: 'no client-side Aether chatter before the play');
  });

  test('a tapped card leaves the hand and animates before the server replies',
      () async {
    // Measured, the server answers in about 240ms. That is not slow, but a
    // silent gap reads as a freeze, so the tap has to show something at once.
    final unit = _cardView(5, cardId: 'unit-1', type: 'unit');
    final projection = PvpProjection.fromJson({
      'version': 1,
      'activePlayer': 'p1',
      'phase': 'main1',
      'turnNumber': 1,
      'winner': null,
      'chainCount': 0,
      'stage': 'main',
      'priority': 'p1',
      'pendingAttackers': const [],
      'revision': 1,
      'players': {
        'p1': {
          ..._player('p1'),
          'viewer': 'p1',
          'hand': [unit],
          'handCount': 1,
        },
        'p2': {..._player('p2'), 'viewer': 'p1'},
      },
    });

    // A gateway that never answers, so only the immediate feedback is observed.
    final gateway = _SilentGateway(projection);
    final pvp = PvpController(gateway: gateway, userId: 'user-1');
    await pvp.resumeActiveMatch();
    final duel = PvpDuelController(
      pvp: pvp,
      library: _costedLibrary,
      deck: const [],
    );
    expect(duel.me.hand.length, 1, reason: 'the card starts in hand');

    duel.playHandCard(5);

    expect(duel.me.hand, isEmpty, reason: 'the card left the hand on the tap');
    expect(
      duel.pendingEvents.where((e) => e.kind == 'play').map((e) => e.instanceId),
      contains(5),
      reason: 'the play animation starts on the tap',
    );
    duel.dispose();
  });

  test('ending the turn keeps going until the seat actually changes', () async {
    // One nextPhase from Main 1 lands in Combat. Stopping there would leave the
    // player mid-turn having pressed "end turn", and combat cannot be left
    // without declaring attackers.
    final main1 = _projection(viewer: 'p1', activePlayer: 'p1');
    final combat = _projection(
      viewer: 'p1',
      activePlayer: 'p1',
      stage: 'attackDeclaration',
    );
    final opponent = _projection(viewer: 'p1', activePlayer: 'p2');

    final gateway = _Gateway(main1)..replies = [combat, main1, opponent];
    final pvp = PvpController(gateway: gateway, userId: 'user-1');
    await pvp.resumeActiveMatch();
    final duel = PvpDuelController(
      pvp: pvp,
      library: _library,
      deck: const [],
    );

    await duel.endTurn();
    duel.dispose();

    final sent = gateway.commands.map((c) => c.type).toList();
    expect(sent, contains(PvpCommandType.declareAttackers),
        reason: 'combat has to be cleared to leave it');
    expect(pvp.projection?.activePlayer, PlayerId.p2);
  });

  test('conceding sends the command rather than ending locally', () async {
    final gateway = _Gateway(_projection(viewer: 'p1'));
    final pvp = PvpController(gateway: gateway, userId: 'user-1');
    await pvp.resumeActiveMatch();
    final duel = PvpDuelController(
      pvp: pvp,
      library: _library,
      deck: const [],
    );

    duel.surrender();
    await Future<void>.delayed(Duration.zero);

    expect(
      gateway.commands.map((c) => c.type),
      contains(PvpCommandType.concede),
    );
    duel.dispose();
  });
}
