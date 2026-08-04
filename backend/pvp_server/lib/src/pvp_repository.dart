import 'package:shardfall_engine/shardfall_engine.dart';

class PersistedMatch {
  final String id;
  final String playerOneId;
  final String playerTwoId;
  final String status;
  final String engineVersion;
  final String rulesetVersion;
  final PvpSession session;
  final Map<String, Map<String, dynamic>> projectionsByUser;
  final Map<String, DateTime> lastHeartbeatByUser;
  final DateTime updatedAt;

  PersistedMatch({
    required this.id,
    required this.playerOneId,
    required this.playerTwoId,
    required this.status,
    required this.session,
    required this.engineVersion,
    required this.rulesetVersion,
    Map<String, Map<String, dynamic>> projectionsByUser = const {},
    Map<String, DateTime> lastHeartbeatByUser = const {},
    DateTime? updatedAt,
  })  : projectionsByUser = {
          for (final entry in projectionsByUser.entries)
            entry.key: Map<String, dynamic>.from(entry.value),
        },
        lastHeartbeatByUser = Map<String, DateTime>.from(lastHeartbeatByUser),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  PersistedMatch copyWith({
    String? status,
    PvpSession? session,
    Map<String, Map<String, dynamic>>? projectionsByUser,
    Map<String, DateTime>? lastHeartbeatByUser,
    DateTime? updatedAt,
  }) =>
      PersistedMatch(
        id: id,
        playerOneId: playerOneId,
        playerTwoId: playerTwoId,
        status: status ?? this.status,
        engineVersion: engineVersion,
        rulesetVersion: rulesetVersion,
        session: session ?? this.session,
        projectionsByUser: projectionsByUser ?? this.projectionsByUser,
        lastHeartbeatByUser: lastHeartbeatByUser ?? this.lastHeartbeatByUser,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      );

  bool hasPlayer(String userId) =>
      userId == playerOneId || userId == playerTwoId;

  PlayerId seatOf(String userId) {
    if (userId == playerOneId) return PlayerId.p1;
    if (userId == playerTwoId) return PlayerId.p2;
    throw StateError('User is not a player in this match');
  }
}

class PvpCommandResponse {
  final String matchId;
  final bool accepted;
  final bool duplicate;
  final int revision;
  final String status;
  final Map<String, dynamic> projection;
  final List<Map<String, dynamic>> events;
  final String? errorCode;
  final String? message;

  const PvpCommandResponse({
    required this.matchId,
    required this.accepted,
    required this.duplicate,
    required this.revision,
    required this.status,
    required this.projection,
    required this.events,
    this.errorCode,
    this.message,
  });

  PvpCommandResponse copyWith({bool? duplicate}) => PvpCommandResponse(
        matchId: matchId,
        accepted: accepted,
        duplicate: duplicate ?? this.duplicate,
        revision: revision,
        status: status,
        projection: projection,
        events: events,
        errorCode: errorCode,
        message: message,
      );

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'accepted': accepted,
        'duplicate': duplicate,
        'revision': revision,
        'status': status,
        'projection': projection,
        'events': events,
        if (errorCode != null) 'errorCode': errorCode,
        if (message != null) 'message': message,
      };
}

class PvpReconnectResponse {
  final String matchId;
  final int revision;
  final String status;
  final Map<String, dynamic> projection;
  final String? errorCode;
  final String? message;

  const PvpReconnectResponse({
    required this.matchId,
    required this.revision,
    required this.status,
    required this.projection,
    this.errorCode,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'revision': revision,
        'status': status,
        'projection': projection,
        if (errorCode != null) 'errorCode': errorCode,
        if (message != null) 'message': message,
      };
}

class PvpCommandRecord {
  final String matchId;
  final String actorUserId;
  final String idempotencyKey;
  final PvpCommandType commandType;
  final String result;
  final PvpCommandResponse response;
  final DateTime createdAt;

  PvpCommandRecord({
    required this.matchId,
    required this.actorUserId,
    required this.idempotencyKey,
    required this.commandType,
    required this.result,
    required this.response,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();
}

class PvpEventRecord {
  final String matchId;
  final int sequence;
  final int revision;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  PvpEventRecord({
    required this.matchId,
    this.sequence = 0,
    required this.revision,
    required this.eventType,
    this.payload = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();
}

abstract interface class PvpRepository {
  Future<PersistedMatch?> getMatch(String matchId);

  Future<PvpCommandRecord?> findCommand(
    String matchId,
    String actorUserId,
    String idempotencyKey,
  );

  Future<T> withMatchLock<T>(
    String matchId,
    Future<T> Function() action,
  );

  Future<void> commitTransition({
    required PersistedMatch before,
    required PersistedMatch after,
    required PvpCommandRecord command,
    required List<PvpEventRecord> events,
  });

  Future<void> touchPlayer(String matchId, String userId);
}
