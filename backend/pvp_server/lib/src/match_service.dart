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
        final match = await repository.getMatch(matchId);
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

        final previous = await repository.findCommand(
          matchId,
          actorUserId,
          command.idempotencyKey,
        );
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

        final result = PvpEngine.apply(baseSession, actor, command);
        final nextDeadline =
            TurnClock.deadlineFor(result.session, DateTime.now().toUtc());
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
        final projections = {
          ...match.projectionsByUser,
          match.playerOneId:
              PvpCodec.encodeProjection(result.session, PlayerId.p1),
          match.playerTwoId:
              PvpCodec.encodeProjection(result.session, PlayerId.p2),
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
        return response;
      });


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
