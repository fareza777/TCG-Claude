import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/pvp/pvp_controller.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall/pvp/pvp_service.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  test('join queue reports queued state', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'queued'),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    await controller.join(List<String>.filled(40, 'sproutling'));

    expect(controller.state, PvpConnectionState.queued);
    expect(gateway.joinedDeck.length, 40);
    controller.dispose();
  });

  test('resumes a match left running by a previous session', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'queued'),
      reconnectProjection: _projection(revision: 2, stage: 'main'),
    )..activeMatchId = 'match-in-progress';
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    final resumed = await controller.resumeActiveMatch();

    expect(resumed, isTrue);
    expect(controller.matchId, 'match-in-progress');
    expect(controller.state, PvpConnectionState.active);
    controller.dispose();
  });

  test('reports nothing to resume when no match is live', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'queued'),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    expect(await controller.resumeActiveMatch(), isFalse);
    expect(controller.matchId, isNull);
    controller.dispose();
  });

  test('an already-in-match rejection rejoins instead of erroring', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'queued'),
      reconnectProjection: _projection(revision: 3, stage: 'main'),
    )
      ..activeMatchId = 'match-in-progress'
      ..joinError = const PvpServiceException(
        'already_in_match',
        code: 'already_in_match',
      );
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    await controller.join(List<String>.filled(40, 'sproutling'));

    // The player lands back in their match rather than seeing a dead end.
    expect(controller.matchId, 'match-in-progress');
    expect(controller.state, PvpConnectionState.active);
    expect(controller.lastError, isNull);
    controller.dispose();
  });

  test('queued player attaches when realtime reports a paired match', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'queued'),
      reconnectProjection: _projection(revision: 0, stage: 'waitingForReady'),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    await controller.join(List<String>.filled(40, 'sproutling'));
    gateway.queueMatches.add('match-queued');
    await Future<void>.delayed(Duration.zero);

    expect(controller.matchId, 'match-queued');
    expect(controller.state, PvpConnectionState.active);
    controller.dispose();
  });

  test('matched queue reconnects and starts the projection stream', () async {
    final projection = _projection(revision: 4, stage: 'main');
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: projection,
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');

    await controller.join(List<String>.filled(40, 'sproutling'));

    expect(controller.state, PvpConnectionState.active);
    expect(controller.matchId, 'match-1');
    expect(controller.projection?.revision, 4);
    expect(gateway.watchedMatchId, 'match-1');
    controller.dispose();
  });

  test(
    'command uses current revision and projection updates from gateway',
    () async {
      final initial = _projection(revision: 2, stage: 'main');
      final after = _projection(revision: 3, stage: 'main');
      final gateway = _FakePvpGateway(
        queueResult: const PvpQueueResult(
          status: 'matched',
          matchId: 'match-1',
        ),
        reconnectProjection: initial,
        commandResponse: PvpCommandResponse(
          accepted: true,
          status: 'active',
          projection: after,
        ),
      );
      final controller = PvpController(gateway: gateway, userId: 'user-1');
      await controller.join(List<String>.filled(40, 'sproutling'));

      await controller.send(
        const PvpCommand(
          type: PvpCommandType.nextPhase,
          idempotencyKey: '00000000-0000-4000-8000-000000000002',
          revision: 0,
        ),
      );

      expect(gateway.commands.single.revision, 2);
      expect(gateway.commands.single.type, PvpCommandType.nextPhase);
      expect(controller.projection?.revision, 3);
      expect(controller.lastError, isNull);
      controller.dispose();
    },
  );

  test('realtime projection advances the visible state', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: _projection(revision: 1, stage: 'main'),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');
    await controller.join(List<String>.filled(40, 'sproutling'));

    gateway.projections.add(_projection(revision: 5, stage: 'finished'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.projection?.revision, 5);
    expect(controller.state, PvpConnectionState.finished);
    controller.dispose();
  });

  test('match events from the realtime stream queue for animation', () async {
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: _projection(revision: 1, stage: 'main'),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');
    await controller.join(List<String>.filled(40, 'sproutling'));

    gateway.matchEvents.add(
      const PvpMatchEvent(
        seq: 1,
        type: 'card_played',
        payload: {'instanceId': 7},
      ),
    );
    gateway.matchEvents.add(
      const PvpMatchEvent(
        seq: 1,
        type: 'card_played',
        payload: {'instanceId': 7},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.pendingMatchEvents.map((event) => event.type),
      ['card_played'],
      reason: 'a repeated sequence number is the same event seen twice',
    );
    controller.dispose();
  });

  test('commands leave one at a time, each stamped with the fresh revision',
      () async {
    // Two taps in the same beat used to race: both carried the same revision,
    // and whichever landed second was rejected as stale.
    final initial = _projection(revision: 2, stage: 'main');
    final after = _projection(revision: 3, stage: 'main');
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: initial,
      commandResponse: PvpCommandResponse(
        accepted: true,
        status: 'active',
        projection: after,
      ),
    );
    final controller = PvpController(gateway: gateway, userId: 'user-1');
    await controller.join(List<String>.filled(40, 'sproutling'));

    final first = controller.send(
      const PvpCommand(
        type: PvpCommandType.nextPhase,
        idempotencyKey: 'tap-one',
        revision: 0,
      ),
    );
    final second = controller.send(
      const PvpCommand(
        type: PvpCommandType.nextPhase,
        idempotencyKey: 'tap-two',
        revision: 0,
      ),
    );
    await Future.wait([first, second]);

    expect(
      gateway.commands.map((command) => command.revision),
      [2, 3],
      reason: 'the second tap rides the revision the first reply made current',
    );
    controller.dispose();
  });

  test('a stale ready is retried once against the fresh board', () async {
    // Both players click through the mulligan window at the same time; the
    // slower click is honest, just early, so the client resyncs and retries
    // instead of showing an error.
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: _projection(revision: 0, stage: 'waitingForReady'),
    );
    gateway.replies = [
      PvpCommandResponse(
        accepted: false,
        status: 'active',
        errorCode: 'stale_revision',
        message: 'The command was based on an old match revision.',
        projection: _projection(revision: 1, stage: 'waitingForReady'),
      ),
      PvpCommandResponse(
        accepted: true,
        status: 'active',
        projection: _projection(revision: 2, stage: 'main'),
      ),
    ];
    final controller = PvpController(gateway: gateway, userId: 'user-1');
    await controller.join(List<String>.filled(40, 'sproutling'));

    await controller.ready();

    expect(gateway.commands.length, 2);
    expect(
      gateway.commands.last.revision,
      1,
      reason: 'the retry carries the revision the rejection delivered',
    );
    expect(controller.lastError, isNull);
    controller.dispose();
  });

  test('a rejected heartbeat never surfaces as an error', () async {
    // Presence is retried on the next tick; there is nothing for the player
    // to act on, so it must not paint the error banner.
    final gateway = _FakePvpGateway(
      queueResult: const PvpQueueResult(status: 'matched', matchId: 'match-1'),
      reconnectProjection: _projection(revision: 1, stage: 'main'),
    );
    gateway.replies = [
      const PvpCommandResponse(
        accepted: false,
        status: 'active',
        errorCode: 'stale_revision',
        message: 'The command was based on an old match revision.',
      ),
    ];
    final controller = PvpController(gateway: gateway, userId: 'user-1');
    await controller.join(List<String>.filled(40, 'sproutling'));

    await controller.send(
      const PvpCommand(
        type: PvpCommandType.heartbeat,
        idempotencyKey: 'presence-tick',
        revision: 1,
      ),
    );

    expect(controller.lastError, isNull);
    expect(controller.state, PvpConnectionState.active);
    controller.dispose();
  });
}

PvpProjection _projection({required int revision, required String stage}) {
  Map<String, dynamic> player(String id, String viewer) => {
    'id': id,
    'health': 25,
    'hand': const [],
    'handCount': 0,
    'deckCount': 40,
    'arena': const [],
    'ruins': const [],
    'ruinsCount': 0,
    'voidCount': 0,
    'aetherPool': const {},
    'playedWellspringThisTurn': false,
    'usedAttuneThisTurn': false,
    'viewer': viewer,
  };
  return PvpProjection.fromJson({
    'version': 1,
    'activePlayer': 'p1',
    'phase': 'main1',
    'turnNumber': 1,
    'winner': stage == 'finished' ? 'p2' : null,
    'chainCount': 0,
    'stage': stage,
    'priority': 'p1',
    'pendingAttackers': const [],
    'revision': revision,
    'players': {'p1': player('p1', 'p1'), 'p2': player('p2', 'p1')},
  });
}

class _FakePvpGateway implements PvpGateway {
  _FakePvpGateway({
    required this.queueResult,
    this.reconnectProjection,
    this.commandResponse,
  });

  final PvpQueueResult queueResult;
  final PvpProjection? reconnectProjection;
  final PvpCommandResponse? commandResponse;
  final projections = StreamController<PvpProjection>.broadcast();
  final matchEvents = StreamController<PvpMatchEvent>.broadcast();
  final queueMatches = StreamController<String>.broadcast();
  final commands = <PvpCommand>[];
  List<String> joinedDeck = const [];
  String? watchedMatchId;

  /// The match the server still holds for this player, if any.
  String? activeMatchId;
  Object? joinError;

  @override
  Future<PvpQueueResult> joinQueue(List<String> deckSnapshot) async {
    joinedDeck = deckSnapshot;
    final error = joinError;
    if (error != null) throw error;
    return queueResult;
  }

  @override
  Future<String?> findActiveMatch() async => activeMatchId;

  @override
  Future<void> leaveQueue() async {}

  /// Responses handed out in order, so a stale-then-retry flow can be
  /// scripted. Falls back to [commandResponse] once the list runs out.
  List<PvpCommandResponse> replies = const [];
  int _reply = 0;

  @override
  Future<PvpCommandResponse> sendCommand(
    String matchId,
    PvpCommand command,
  ) async {
    commands.add(command);
    if (_reply < replies.length) return replies[_reply++];
    return commandResponse ??
        PvpCommandResponse(accepted: true, status: 'active');
  }

  @override
  Future<PvpProjection> reconnect(String matchId) async {
    return reconnectProjection!;
  }

  @override
  Stream<PvpProjection> watchMatch(
    String matchId,
    String userId, {
    int Function()? appliedRevision,
  }) {
    watchedMatchId = matchId;
    return projections.stream;
  }

  @override
  Stream<PvpMatchEvent> watchEvents(String matchId) => matchEvents.stream;

  @override
  Stream<String> watchQueue(String userId) => queueMatches.stream;

  @override
  void dispose() {
    projections.close();
    matchEvents.close();
    queueMatches.close();
  }
}
