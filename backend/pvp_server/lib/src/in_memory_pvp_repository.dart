import 'dart:async';

import 'pvp_repository.dart';

/// Small deterministic repository used by unit tests and local smoke tests.
/// The production implementation will replace its commit operation with a
/// Postgres transaction/CAS RPC while keeping the same service boundary.
class InMemoryPvpRepository implements PvpRepository {
  final Map<String, PersistedMatch> _matches = {};
  final Map<String, PvpCommandRecord> _commands = {};
  final List<PvpEventRecord> events = [];
  final Map<String, Future<void>> _locks = {};
  int _nextEventSequence = 1;

  void putMatch(PersistedMatch match) => _matches[match.id] = match;

  @override
  Future<PersistedMatch?> getMatch(String matchId) async => _matches[matchId];

  @override
  Future<void> initializeMatch(PersistedMatch match) async {
    _matches.putIfAbsent(match.id, () => match);
  }

  @override
  Future<PvpCommandRecord?> findCommand(
    String matchId,
    String actorUserId,
    String idempotencyKey,
  ) async =>
      _commands[_commandKey(matchId, actorUserId, idempotencyKey)];

  @override
  Future<T> withMatchLock<T>(
    String matchId,
    Future<T> Function() action,
  ) async {
    final previous = _locks[matchId] ?? Future<void>.value();
    final release = Completer<void>();
    final releaseFuture = release.future;
    _locks[matchId] = releaseFuture;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_locks[matchId], releaseFuture)) {
        _locks.remove(matchId);
      }
    }
  }

  @override
  Future<void> commitTransition({
    required PersistedMatch before,
    required PersistedMatch after,
    required PvpCommandRecord command,
    required List<PvpEventRecord> events,
  }) async {
    final current = _matches[before.id];
    if (current == null) throw StateError('match_not_found');
    if (current.session.revision != before.session.revision) {
      throw StateError('revision_conflict');
    }
    final key = _commandKey(
      command.matchId,
      command.actorUserId,
      command.idempotencyKey,
    );
    if (_commands.containsKey(key)) throw StateError('duplicate_command');
    _matches[after.id] = after;
    _commands[key] = command;
    for (final event in events) {
      this.events.add(PvpEventRecord(
            matchId: event.matchId,
            sequence: _nextEventSequence,
            revision: event.revision,
            eventType: event.eventType,
            payload: event.payload,
            createdAt: event.createdAt,
          ));
      _nextEventSequence++;
    }
  }

  @override
  Future<void> touchPlayer(String matchId, String userId) async {
    final match = _matches[matchId];
    if (match == null || !match.hasPlayer(userId)) return;
    _matches[matchId] = match.copyWith(
      lastHeartbeatByUser: {
        ...match.lastHeartbeatByUser,
        userId: DateTime.now().toUtc(),
      },
    );
  }

  static String _commandKey(
    String matchId,
    String actorUserId,
    String idempotencyKey,
  ) =>
      '$matchId|$actorUserId|$idempotencyKey';
}
