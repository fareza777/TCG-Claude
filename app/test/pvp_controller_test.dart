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
  Future<List<PvpMatchEvent>> eventsSince(String matchId, int afterSeq) async =>
      const [];

  @override
  Future<void> leaveQueue() async {}

  @override
  Future<PvpCommandResponse> sendCommand(
    String matchId,
    PvpCommand command,
  ) async {
    commands.add(command);
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
  Stream<String> watchQueue(String userId) => queueMatches.stream;

  @override
  void dispose() {
    projections.close();
    queueMatches.close();
  }
}
