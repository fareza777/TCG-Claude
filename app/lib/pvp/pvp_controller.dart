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

  /// Public events the battle screen has not animated yet, oldest first.
  final List<PvpMatchEvent> pendingMatchEvents = [];
  int _lastEventSeq = 0;

  /// Hands over the queued events and clears them, mirroring how the
  /// single-player controller drains its own animation queue.
  List<PvpMatchEvent> takeMatchEvents() {
    final events = List<PvpMatchEvent>.of(pendingMatchEvents);
    pendingMatchEvents.clear();
    return events;
  }

  StreamSubscription<PvpProjection>? _matchSubscription;
  StreamSubscription<PvpMatchEvent>? _eventSubscription;
  StreamSubscription<String>? _queueSubscription;
  Timer? _queuePoll;
  Timer? _heartbeat;

  /// Rejoins a match left running by a previous session.
  ///
  /// [matchId] only lives in memory, so closing the app loses it while the
  /// server still holds the match. Returns true once attached.
  Future<bool> resumeActiveMatch() async {
    try {
      final id = await gateway.findActiveMatch();
      if (id == null) return false;
      await _attachToMatch(id);
      return true;
    } catch (error) {
      _setError(_messageFor(error));
      return false;
    }
  }

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
      // The server refuses to queue while a match is live. That is a signal to
      // rejoin it, not an error to show the player.
      if (_isAlreadyInMatch(error) && await resumeActiveMatch()) return;
      _setError(_messageFor(error));
    }
  }

  bool _isAlreadyInMatch(Object error) {
    final text = error is PvpServiceException
        ? '${error.code ?? ''} ${error.message}'
        : error.toString();
    return text.contains('already_in_match') ||
        text.contains('already has an active match');
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

  /// Commands leave one at a time, each stamped with the freshest revision
  /// at the moment it actually goes out. Two quick taps used to race: the
  /// second carried the revision the first had just made stale, and the
  /// server answered with a cryptic "old match revision" rejection.
  Future<void> _outbox = Future<void>.value();

  Future<void> send(PvpCommand command) {
    final run = _outbox.then((_) => _sendNow(command));
    _outbox = run.catchError((_) {});
    return run;
  }

  Future<void> _sendNow(PvpCommand command) async {
    final id = matchId;
    if (id == null || projection == null) {
      _setError('Join a PvP match before sending commands.');
      return;
    }
    if (!pendingCommands.add(command.idempotencyKey)) return;

    var retried = false;
    try {
      while (true) {
        final current = projection;
        if (current == null) return;
        final outbound = PvpCommand(
          type: command.type,
          idempotencyKey: command.idempotencyKey,
          revision: current.revision,
          payload: command.payload,
        );
        final response = await gateway
            .sendCommand(id, outbound)
            .timeout(const Duration(seconds: 15));
        if (response.projection != null) _applyProjection(response.projection!);
        if (response.accepted) {
          if (response.status == 'finished' ||
              projection?.isFinished == true) {
            _setState(PvpConnectionState.finished);
          } else {
            _setState(PvpConnectionState.active);
          }
          return;
        }
        // Presence retries on its own tick; a rejected heartbeat says nothing
        // the player can act on, so it never surfaces as an error banner.
        if (command.type == PvpCommandType.heartbeat) return;
        if (response.errorCode == 'stale_revision') {
          await _resync(id);
          // The ready and mulligan windows are the one place both players act
          // at once, so an honest command can arrive stale there through no
          // fault of the player. Retry it once against the fresh board
          // instead of reporting a failure.
          if (!retried &&
              (command.type == PvpCommandType.ready ||
                  command.type == PvpCommandType.redraw)) {
            retried = true;
            continue;
          }
          lastErrorCode = 'stale_revision';
          _setError(
            'The board changed just as that move landed. It was not applied, try again.',
          );
          return;
        }
        lastErrorCode = response.errorCode;
        _setError(response.message ?? 'That move is not legal right now.');
        return;
      }
    } catch (error) {
      if (command.type != PvpCommandType.heartbeat) {
        _setError(_messageFor(error));
      }
    } finally {
      pendingCommands.remove(command.idempotencyKey);
    }
  }

  /// Pulls the current board after a stale rejection, without tearing down
  /// the live subscriptions the way a full reconnect does.
  Future<void> _resync(String id) async {
    try {
      _applyProjection(await _reconnectWithRetry(id));
    } catch (_) {
      // The next realtime push heals the board anyway.
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

  /// "Pass until the turn changes hands" as one round trip. The server
  /// expands it into the phase steps the client used to send one by one.
  Future<void> endTurn() => send(_command(PvpCommandType.endTurn));

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
    // The queue watcher and its fallback poll can both spot the pairing at
    // the same time; attaching twice would double every subscription.
    if (matchId != null) return;
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
    // A freshly paired match can still be initializing on the server, and a
    // sleeping service needs a couple of seconds to wake. The old window of
    // roughly 1.5 seconds gave up before either had finished.
    const delays = [400, 800, 1200, 1600, 2000, 2000, 2000];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        return await gateway.reconnect(id);
      } catch (error) {
        lastError = error;
        if (attempt == delays.length) rethrow;
        await Future<void>.delayed(Duration(milliseconds: delays[attempt]));
      }
    }
    throw lastError ?? const PvpServiceException('PvP reconnect failed.');
  }

  Future<void> _startWatching(String id) async {
    await _queueSubscription?.cancel();
    _queueSubscription = null;
    _queuePoll?.cancel();
    _queuePoll = null;
    await _matchSubscription?.cancel();
    _matchSubscription = gateway
        .watchMatch(id, userId, appliedRevision: () => projection?.revision ?? -1)
        .listen(
          _applyProjection,
          onError: (Object error, StackTrace stack) {
            if (state != PvpConnectionState.finished) {
              _setError(_messageFor(error));
            }
          },
        );
    await _eventSubscription?.cancel();
    // Animation cues ride the realtime event stream now. They used to be
    // polled from the events table after every projection, so the board
    // visibly changed first and the animations chased it a beat later.
    _eventSubscription = gateway.watchEvents(id).listen(
      (event) {
        if (event.seq <= _lastEventSeq) return;
        _lastEventSeq = event.seq;
        pendingMatchEvents.add(event);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        // Animation cues are decoration; the board is already correct without
        // them, so a failure here must never disturb the match.
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
    // Realtime almost always delivers the pairing, but "almost" strands a
    // waiting player on the search screen. A slow poll is the backstop.
    _queuePoll?.cancel();
    _queuePoll = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (matchId != null || state != PvpConnectionState.queued) return;
      try {
        final id = await gateway.findActiveMatch();
        if (id != null && matchId == null) {
          await _attachToMatch(id);
        }
      } catch (_) {
        // The next tick tries again.
      }
    });
  }

  /// Drops a stale failure so the next command's outcome can be read cleanly.
  void clearError() {
    if (lastError == null && lastErrorCode == null) return;
    lastError = null;
    lastErrorCode = null;
    notifyListeners();
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
    _queuePoll?.cancel();
    _queuePoll = null;
    await _queueSubscription?.cancel();
    _queueSubscription = null;
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
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
    _queuePoll?.cancel();
    unawaited(_queueSubscription?.cancel());
    unawaited(_matchSubscription?.cancel());
    unawaited(_eventSubscription?.cancel());
    gateway.dispose();
    super.dispose();
  }
}
