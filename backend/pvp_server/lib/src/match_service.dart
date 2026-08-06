import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_repository.dart';
import 'turn_clock.dart';

/// A session advanced past decision windows whose clock has run out.
class _OverdueResult {
  const _OverdueResult(this.session, this.events);
  final PvpSession session;
  final List<PvpEvent> events;
}

class MatchService {
  final PvpRepository repository;
  final CardLibrary? cardLibrary;
  final String engineVersion;
  final String rulesetVersion;

  MatchService({
    required this.repository,
    this.cardLibrary,
    this.engineVersion = 'pvp-engine-v1',
    this.rulesetVersion = 'set01-v1',
  });

  Future<bool> initialize({
    required String matchId,
    required String playerOneId,
    required String playerTwoId,
    required List<String> deckP1Ids,
    required List<String> deckP2Ids,
    required int seed,
  }) async {
    final existing = await repository.getMatch(matchId);
    if (existing != null) return true;
    final library = cardLibrary;
    if (library == null) throw StateError('card library is not configured');
    final deckP1 = [for (final id in deckP1Ids) library.card(id)];
    final deckP2 = [for (final id in deckP2Ids) library.card(id)];
    final session = PvpEngine.create(
      deckP1: deckP1,
      deckP2: deckP2,
      seed: seed,
    );
    final projections = {
      playerOneId: PvpCodec.encodeProjection(session, PlayerId.p1),
      playerTwoId: PvpCodec.encodeProjection(session, PlayerId.p2),
    };
    await repository.initializeMatch(PersistedMatch(
      id: matchId,
      playerOneId: playerOneId,
      playerTwoId: playerTwoId,
      status: 'starting',
      engineVersion: engineVersion,
      rulesetVersion: rulesetVersion,
      session: session,
      projectionsByUser: projections,
    ));
    return true;
  }

  Future<PvpCommandResponse> command({
    required String matchId,
    required String actorUserId,
    required PvpCommand command,
  }) =>
      repository.withMatchLock(matchId, () async {
        // The two reads do not depend on each other, so they run together and
        // the command pays one round trip of read latency instead of two.
        final matchFuture = repository.getMatch(matchId);
        final previousFuture = repository.findCommand(
          matchId,
          actorUserId,
          command.idempotencyKey,
        );
        final match = await matchFuture;
        if (match == null) {
          return _commandError(
            matchId,
            'match_not_found',
            'Match does not exist.',
          );
        }
        if (!match.hasPlayer(actorUserId)) {
          return _commandError(
            matchId,
            'not_a_player',
            'The account is not a member of this match.',
            match: match,
          );
        }

        final previous = await previousFuture;
        if (previous != null) {
          return previous.response.copyWith(duplicate: true);
        }

        final actor = match.seatOf(actorUserId);

        // Anyone who has run out of time forfeits their decision before this
        // command is looked at. Enforcement lives here, inside the match lock,
        // because the waiting player's own traffic is what drives it -- a
        // stalling opponent cannot decline to run the clock on themselves.
        final overdue = _applyExpiredWindows(match.session, match.turnDeadline);
        final baseSession = overdue.session;

        final result = command.type == PvpCommandType.endTurn
            ? _applyEndTurn(baseSession, actor, command)
            : PvpEngine.apply(baseSession, actor, command);
        // A refusal changes nothing, so it must not restart the clock either:
        // otherwise spamming illegal moves would extend a stall window
        // indefinitely.
        final nextDeadline = result.accepted
            ? TurnClock.deadlineFor(result.session, DateTime.now().toUtc())
            : match.turnDeadline;
        final projection = _withClock(
          PvpCodec.encodeProjection(result.session, actor),
          nextDeadline,
        );
        final allEvents = [...overdue.events, ...result.events];
        final eventJson = [
          for (final event in allEvents) {'type': event.type, ...event.payload},
        ];
        final status = _statusFor(match.status, result.session);
        final response = PvpCommandResponse(
          matchId: matchId,
          accepted: result.accepted,
          duplicate: false,
          revision: result.session.revision,
          status: status,
          projection: projection,
          events: eventJson,
          errorCode: result.error?.code,
          message: result.error?.message,
        );
        // The stored projections are what the clients' realtime subscriptions
        // push, so they carry the clock too -- otherwise the pushed board
        // would show a blank timer until the next command response.
        final projections = {
          ...match.projectionsByUser,
          match.playerOneId: _withClock(
            PvpCodec.encodeProjection(result.session, PlayerId.p1),
            nextDeadline,
          ),
          match.playerTwoId: _withClock(
            PvpCodec.encodeProjection(result.session, PlayerId.p2),
            nextDeadline,
          ),
        };
        final after = match.copyWith(
          session: result.session,
          status: status,
          projectionsByUser: projections,
          turnDeadline: nextDeadline,
        );
        final commandRecord = PvpCommandRecord(
          matchId: matchId,
          actorUserId: actorUserId,
          idempotencyKey: command.idempotencyKey,
          commandType: command.type,
          payload: command.payload,
          result: result.accepted ? 'accepted' : 'rejected',
          response: response,
        );
        final events = [
          for (final event in allEvents)
            PvpEventRecord(
              matchId: matchId,
              revision: result.session.revision,
              eventType: event.type,
              payload: event.payload,
            ),
        ];
        await repository.commitTransition(
          before: match,
          after: after,
          command: commandRecord,
          events: events,
        );
        // Presence is what the stale-match reaper reads, and only heartbeat
        // traffic keeps it fresh during a long match. Without this stamp a
        // match with two active players looked abandoned after fifteen
        // minutes and was cancelled out from under them.
        if (command.type == PvpCommandType.heartbeat && result.accepted) {
          try {
            await repository.touchPlayer(matchId, actorUserId);
          } catch (_) {
            // Presence is best-effort; never fail a command over it.
          }
        }
        return response;
      });

  /// "End turn" expanded into the real sub-commands, inside the one lock.
  ///
  /// The client used to walk the phases itself: nextPhase into combat, an
  /// empty attack declaration to leave it, nextPhase again -- each a full
  /// network round trip, so ending a turn took seconds of visible waiting.
  /// Expanding the composite here costs one round trip, and every step still
  /// goes through the engine, so the rules are identical to pressing the
  /// buttons by hand.
  PvpCommandResult _applyEndTurn(
    PvpSession session,
    PlayerId actor,
    PvpCommand command,
  ) {
    if (command.revision != session.revision) {
      return PvpCommandResult(
        session: session,
        error: const PvpRuleError(
          'stale_revision',
          'The command was based on an old match revision.',
        ),
      );
    }
    var current = session;
    final events = <PvpEvent>[];
    var applied = 0;
    for (var guard = 0; guard < 8; guard++) {
      if (current.stage == PvpStage.finished) break;
      if (current.game.activePlayer != actor) break;
      final subType = switch (current.stage) {
        PvpStage.main => PvpCommandType.nextPhase,
        PvpStage.attackDeclaration => PvpCommandType.declareAttackers,
        // Chain priority, block declaration, ready windows: the decision
        // belongs to someone specific, so the turn cannot be pushed further.
        _ => null,
      };
      if (subType == null) break;
      final step = PvpEngine.apply(
        current,
        actor,
        PvpCommand(
          type: subType,
          idempotencyKey: '${command.idempotencyKey}:$guard',
          revision: current.revision,
          payload: subType == PvpCommandType.declareAttackers
              ? const {'attackerIds': <int>[]}
              : const {},
        ),
      );
      if (!step.accepted) {
        // A refusal on the first step is the answer to give the player; after
        // progress has been made it just marks where the walk had to stop.
        if (applied == 0) return step;
        break;
      }
      current = step.session;
      events.addAll(step.events);
      applied++;
    }
    if (applied == 0) {
      return PvpCommandResult(
        session: session,
        error: const PvpRuleError(
          'illegal_stage',
          'End turn is not available now.',
        ),
      );
    }
    return PvpCommandResult(session: current, events: events);
  }


  /// Forfeits any decision whose deadline has passed.
  ///
  /// Only one window is resolved per call. A player who has simply walked away
  /// therefore loses their windows one at a time as the opponent's traffic
  /// arrives, rather than having a whole game played out for them in a single
  /// burst. Total absence is handled separately by the stale-match reaper.
  _OverdueResult _applyExpiredWindows(PvpSession session, DateTime? deadline) {
    if (deadline == null) return _OverdueResult(session, const []);
    if (!DateTime.now().toUtc().isAfter(deadline)) {
      return _OverdueResult(session, const []);
    }

    final action = TurnClock.forfeitActionFor(session.stage);
    if (action == null) return _OverdueResult(session, const []);

    final payload = TurnClock.forfeitPayloadFor(session.stage);
    var current = session;
    final events = <PvpEvent>[];

    for (final seat in TurnClock.owedBy(session)) {
      final forfeit = PvpEngine.apply(
        current,
        seat,
        PvpCommand(
          type: action,
          idempotencyKey: 'clock-${current.revision}-${seat.name}',
          revision: current.revision,
          payload: payload,
        ),
      );
      // A refusal here is not worth failing the player's real command over;
      // the next pass will try again.
      if (!forfeit.accepted) continue;
      current = forfeit.session;
      events
        ..add(PvpEvent('turn_clock_expired', payload: {'player': seat.name}))
        ..addAll(forfeit.events);
    }

    return _OverdueResult(current, events);
  }


  /// Adds the live deadline to a projection.
  ///
  /// The clock has to come from the server: a client that invented its own
  /// would disagree with the side actually enforcing it, and the player would
  /// watch a countdown that means nothing.
  Map<String, dynamic> _withClock(
    Map<String, dynamic> projection,
    DateTime? deadline,
  ) =>
      {
        ...projection,
        'deadlineAt': deadline?.toIso8601String(),
      };

  Future<PvpReconnectResponse> reconnect({
    required String matchId,
    required String actorUserId,
  }) =>
      repository.withMatchLock(matchId, () async {
        final match = await repository.getMatch(matchId);
        if (match == null) {
          return _reconnectError(
            matchId,
            'match_not_found',
            'Match does not exist.',
          );
        }
        if (!match.hasPlayer(actorUserId)) {
          return _reconnectError(
            matchId,
            'not_a_player',
            'The account is not a member of this match.',
          );
        }
        await repository.touchPlayer(matchId, actorUserId);
        final seat = match.seatOf(actorUserId);
        final projection = _withClock(
          match.projectionsByUser[actorUserId] ??
              PvpCodec.encodeProjection(match.session, seat),
          match.turnDeadline,
        );
        return PvpReconnectResponse(
          matchId: matchId,
          revision: match.session.revision,
          status: match.status,
          projection: projection,
        );
      });

  static String _statusFor(String current, PvpSession session) {
    if (session.stage == PvpStage.finished) return 'finished';
    if (session.stage == PvpStage.waitingForReady ||
        session.stage == PvpStage.mulligan) {
      return current == 'queued' ? 'starting' : current;
    }
    return 'active';
  }

  static PvpCommandResponse _commandError(
    String matchId,
    String code,
    String message, {
    PersistedMatch? match,
  }) {
    final session = match?.session;
    final projection = session == null
        ? <String, dynamic>{}
        : PvpCodec.encodeProjection(session, PlayerId.p1);
    return PvpCommandResponse(
      matchId: matchId,
      accepted: false,
      duplicate: false,
      revision: session?.revision ?? 0,
      status: match?.status ?? 'unknown',
      projection: projection,
      events: const [],
      errorCode: code,
      message: message,
    );
  }

  static PvpReconnectResponse _reconnectError(
    String matchId,
    String code,
    String message,
  ) =>
      PvpReconnectResponse(
        matchId: matchId,
        revision: 0,
        status: 'unknown',
        projection: const {},
        errorCode: code,
        message: message,
      );
}
