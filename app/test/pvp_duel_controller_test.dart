import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/pvp/pvp_controller.dart';
import 'package:shardfall/pvp/pvp_duel_controller.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall/pvp/pvp_service.dart';

const _library = CardLibrary(byId: {}, starterDecks: {});

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

  @override
  Future<PvpCommandResponse> sendCommand(
    String matchId,
    PvpCommand command,
  ) async {
    commands.add(command);
    return PvpCommandResponse(
      accepted: true,
      duplicate: false,
      status: 'active',
      revision: command.revision + 1,
      projection: projection,
    );
  }

  @override
  Stream<PvpProjection> watchMatch(String id, String userId) =>
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
    expect(
      duel.pendingEvents
          .where((e) => e.kind == 'attack')
          .map((e) => e.instanceId),
      containsAll(<int>[3, 4]),
    );
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
