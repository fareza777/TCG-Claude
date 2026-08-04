import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_models.dart';
import 'pvp_service.dart';

class PvpController extends ChangeNotifier {
  PvpController({required this.gateway, required this.userId});

  final PvpGateway gateway;
  final String userId;

  PvpConnectionState state = PvpConnectionState.idle;
  String? matchId;
  PvpProjection? projection;
  String? lastError;
  String? lastErrorCode;
  final Set<String> pendingCommands = {};

  StreamSubscription<PvpProjection>? _matchSubscription;
  StreamSubscription<String>? _queueSubscription;
  Timer? _heartbeat;

  Future<void> join(List<String> deckSnapshot) async {
    if (deckSnapshot.length != 40) {
      _setError('PvP deck must contain exactly 40 cards.');
      return;
    }
    await _resetConnection();
    _setState(PvpConnectionState.joining);
    try {
      final result = await gateway.joinQueue(deckSnapshot);
      if (result.status == 'queued') {
        await _startWatchingQueue();
        _setState(PvpConnectionState.queued);
        return;
      }
      if (result.matched && result.matchId != null) {
        await _attachToMatch(result.matchId!);
        return;
      }
      _setError(result.message ?? 'The PvP queue returned an unknown state.');
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> reconnect() async {
    final id = matchId;
    if (id == null) return;
    _setState(PvpConnectionState.reconnecting);
    try {
      final next = await _reconnectWithRetry(id);
      _applyProjection(next);
      await _startWatching(id);
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> leave() async {
    try {
      await gateway.leaveQueue();
    } catch (_) {
      // Leaving locally is still safer than keeping a stale lobby open when
      // the network has already disappeared.
    }
    await _resetConnection();
    _setState(PvpConnectionState.idle);
  }

  Future<void> send(PvpCommand command) async {
    final id = matchId;
    final current = projection;
    if (id == null || current == null) {
      _setError('Join a PvP match before sending commands.');
      return;
    }
    if (!pendingCommands.add(command.idempotencyKey)) return;

    final outbound = PvpCommand(
      type: command.type,
      idempotencyKey: command.idempotencyKey,
      revision: current.revision,
      payload: command.payload,
    );
    try {
      final response = await gateway.sendCommand(id, outbound);
      if (response.projection != null) _applyProjection(response.projection!);
      if (!response.accepted) {
        lastErrorCode = response.errorCode;
        _setError(response.message ?? 'That move is not legal right now.');
        if (response.errorCode == 'stale_revision') {
          unawaited(reconnect());
        }
      } else if (response.status == 'finished' ||
          projection?.isFinished == true) {
        _setState(PvpConnectionState.finished);
      } else {
        _setState(PvpConnectionState.active);
      }
    } catch (error) {
      _setError(_messageFor(error));
    } finally {
      pendingCommands.remove(command.idempotencyKey);
    }
  }

  Future<void> ready() => send(_command(PvpCommandType.ready));

  Future<void> redraw() => send(_command(PvpCommandType.redraw));

  Future<void> nextPhase() => send(_command(PvpCommandType.nextPhase));

  Future<void> playWellspring(int instanceId) =>
      send(_command(PvpCommandType.playWellspring, {'instanceId': instanceId}));

  Future<void> exertForAether(int instanceId) =>
      send(_command(PvpCommandType.exertForAether, {'instanceId': instanceId}));

  Future<void> playUnit(int instanceId, {List<Map<String, dynamic>>? targets}) {
    final payload = <String, dynamic>{'instanceId': instanceId};
    if (targets != null) {
      payload['targets'] = targets;
    }
    return send(_command(PvpCommandType.playUnit, payload));
  }

  Future<void> cast(int instanceId, {List<Map<String, dynamic>>? targets}) {
    final payload = <String, dynamic>{'instanceId': instanceId};
    if (targets != null) {
      payload['targets'] = targets;
    }
    return send(_command(PvpCommandType.cast, payload));
  }

  Future<void> declareAttackers(List<int> attackerIds) => send(
    _command(PvpCommandType.declareAttackers, {'attackerIds': attackerIds}),
  );

  Future<void> declareBlocks(List<Map<String, dynamic>> blocks) =>
      send(_command(PvpCommandType.declareBlocks, {'blocks': blocks}));

  Future<void> passPriority() => send(_command(PvpCommandType.passPriority));

  Future<void> concede() => send(_command(PvpCommandType.concede));

  PvpCommand _command(
    PvpCommandType type, [
    Map<String, dynamic> payload = const {},
  ]) => PvpCommand(
    type: type,
    idempotencyKey: newPvpIdempotencyKey(),
    revision: projection?.revision ?? 0,
    payload: payload,
  );

  Future<void> _attachToMatch(String id) async {
    matchId = id;
    _setState(PvpConnectionState.starting);
    try {
      final next = await _reconnectWithRetry(id);
      _applyProjection(next);
      await _startWatching(id);
    } catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<PvpProjection> _reconnectWithRetry(String id) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await gateway.reconnect(id);
      } catch (error) {
        lastError = error;
        if (attempt == 3) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (attempt + 1)),
        );
      }
    }
    throw lastError ?? const PvpServiceException('PvP reconnect failed.');
  }

  Future<void> _startWatching(String id) async {
    await _queueSubscription?.cancel();
    _queueSubscription = null;
    await _matchSubscription?.cancel();
    _matchSubscription = gateway
        .watchMatch(id, userId)
        .listen(
          _applyProjection,
          onError: (Object error, StackTrace stack) {
            if (state != PvpConnectionState.finished) {
              _setError(_messageFor(error));
            }
          },
        );
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      if (state == PvpConnectionState.active) {
        unawaited(send(_command(PvpCommandType.heartbeat)));
      }
    });
  }

  Future<void> _startWatchingQueue() async {
    await _queueSubscription?.cancel();
    _queueSubscription = gateway
        .watchQueue(userId)
        .listen(
          (id) {
            if (matchId == null) {
              unawaited(_attachToMatch(id));
            }
          },
          onError: (Object error, StackTrace stack) {
            if (state == PvpConnectionState.queued) {
              _setError(_messageFor(error));
            }
          },
        );
  }

  void _applyProjection(PvpProjection next) {
    if (projection != null && next.revision < projection!.revision) return;
    projection = next;
    lastError = null;
    lastErrorCode = null;
    _setState(
      next.isFinished ? PvpConnectionState.finished : PvpConnectionState.active,
    );
  }

  Future<void> _resetConnection() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _queueSubscription?.cancel();
    _queueSubscription = null;
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    matchId = null;
    projection = null;
    pendingCommands.clear();
  }

  void _setState(PvpConnectionState next) {
    if (state == next && lastError == null) {
      notifyListeners();
      return;
    }
    state = next;
    notifyListeners();
  }

  void _setError(String message) {
    lastError = message;
    state = PvpConnectionState.error;
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is PvpServiceException) return error.message;
    return 'PvP connection failed. Please try again.';
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    unawaited(_queueSubscription?.cancel());
    unawaited(_matchSubscription?.cancel());
    gateway.dispose();
    super.dispose();
  }
}
