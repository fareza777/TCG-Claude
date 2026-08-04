import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_repository.dart';

class MatchService {
  final PvpRepository repository;
  final String engineVersion;
  final String rulesetVersion;

  MatchService({
    required this.repository,
    this.engineVersion = 'pvp-engine-v1',
    this.rulesetVersion = 'set01-v1',
  });

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
        final result = PvpEngine.apply(match.session, actor, command);
        final projection = PvpCodec.encodeProjection(result.session, actor);
        final eventJson = [
          for (final event in result.events)
            {'type': event.type, ...event.payload},
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
        );
        final commandRecord = PvpCommandRecord(
          matchId: matchId,
          actorUserId: actorUserId,
          idempotencyKey: command.idempotencyKey,
          commandType: command.type,
          result: result.accepted ? 'accepted' : 'rejected',
          response: response,
        );
        final events = [
          for (final event in result.events)
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
        final projection = match.projectionsByUser[actorUserId] ??
            PvpCodec.encodeProjection(match.session, seat);
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
