import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_repository.dart';

class PvpRepositoryException implements Exception {
  final int statusCode;
  final String body;

  const PvpRepositoryException(this.statusCode, this.body);

  @override
  String toString() => 'PvP repository HTTP $statusCode';
}

/// PostgREST repository used by the Cloud Run service.
///
/// All writes use service-only RPCs. The service key exists only in the
/// container environment and is never included in a JSON body or projection.
class SupabasePvpRepository implements PvpRepository {
  final String baseUrl;
  final String serviceKey;
  final CardLibrary cardLibrary;
  final http.Client client;
  final Map<String, Future<void>> _locks = {};

  SupabasePvpRepository({
    required this.baseUrl,
    required this.serviceKey,
    required this.cardLibrary,
    http.Client? client,
  }) : client = client ?? http.Client();

  @override
  Future<PersistedMatch?> getMatch(String matchId) async {
    final matchRows = await _getList('/pvp_matches', {
      'select':
          'id,player_one_id,player_two_id,status,engine_version,ruleset_version,revision,public_state,updated_at,turn_deadline',
      'id': 'eq.$matchId',
      'limit': '1',
    });
    if (matchRows.isEmpty) return null;
    final row = matchRows.single;
    final runtimeRows = await _getList('/pvp_match_runtime', {
      'select': 'engine_state',
      'match_id': 'eq.$matchId',
      'limit': '1',
    });
    if (runtimeRows.isEmpty || runtimeRows.single['engine_state'] is! Map) {
      // Queue pairing creates metadata before the initializer persists the
      // engine. The initializer endpoint can safely call the RPC without a
      // decoded match.
      return null;
    }
    final rawState = Map<String, dynamic>.from(
      runtimeRows.single['engine_state'] as Map,
    );
    if (rawState.isEmpty) return null;
    final players = await _getList('/pvp_match_players', {
      'select': 'user_id,private_state,last_heartbeat_at',
      'match_id': 'eq.$matchId',
    });
    final projections = <String, Map<String, dynamic>>{};
    final heartbeats = <String, DateTime>{};
    for (final player in players) {
      final userId = player['user_id'];
      if (userId is! String) continue;
      final privateState = player['private_state'];
      if (privateState is Map) {
        projections[userId] = Map<String, dynamic>.from(privateState);
      }
      final heartbeat = player['last_heartbeat_at'];
      if (heartbeat is String) {
        final parsed = DateTime.tryParse(heartbeat);
        if (parsed != null) heartbeats[userId] = parsed.toUtc();
      }
    }
    return PersistedMatch(
      id: row['id'] as String,
      playerOneId: row['player_one_id'] as String,
      playerTwoId: row['player_two_id'] as String,
      status: row['status'] as String,
      engineVersion: row['engine_version'] as String,
      rulesetVersion: row['ruleset_version'] as String,
      session: PvpCodec.decodeSession(rawState, cardLibrary),
      projectionsByUser: projections,
      lastHeartbeatByUser: heartbeats,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toUtc(),
      turnDeadline:
          DateTime.tryParse(row['turn_deadline'] as String? ?? '')?.toUtc(),
    );
  }

  @override
  Future<void> initializeMatch(PersistedMatch match) async {
    await _rpc('pvp_initialize_match', {
      'p_match_id': match.id,
      'p_server_seed': match.session.game.rngSeed.toString(),
      'p_engine_version': match.engineVersion,
      'p_ruleset_version': match.rulesetVersion,
      'p_engine_state': PvpCodec.encodeSession(match.session),
      'p_public_state': _publicProjection(match.session),
      'p_player_projections': match.projectionsByUser,
      'p_revision': match.session.revision,
      'p_turn_deadline': null,
    });
  }

  @override
  Future<PvpCommandRecord?> findCommand(
    String matchId,
    String actorUserId,
    String idempotencyKey,
  ) async {
    final rows = await _getList('/pvp_commands', {
      'select':
          'match_id,actor_id,idempotency_key,command_type,payload,result,response,created_at',
      'match_id': 'eq.$matchId',
      'actor_id': 'eq.$actorUserId',
      'idempotency_key': 'eq.$idempotencyKey',
      'limit': '1',
    });
    if (rows.isEmpty) return null;
    final row = rows.single;
    final response = row['response'];
    if (response is! Map) return null;
    return PvpCommandRecord(
      matchId: row['match_id'] as String,
      actorUserId: row['actor_id'] as String,
      idempotencyKey: row['idempotency_key'] as String,
      commandType: PvpCommandType.values.byName(row['command_type'] as String),
      payload: _map(row['payload']),
      result: row['result'] as String,
      response: _responseFromJson(Map<String, dynamic>.from(response)),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toUtc(),
    );
  }

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
      if (identical(_locks[matchId], releaseFuture)) _locks.remove(matchId);
    }
  }

  @override
  Future<void> commitTransition({
    required PersistedMatch before,
    required PersistedMatch after,
    required PvpCommandRecord command,
    required List<PvpEventRecord> events,
  }) async {
    final winnerId = after.session.game.winner == null
        ? null
        : after.session.game.winner == PlayerId.p1
            ? after.playerOneId
            : after.playerTwoId;
    final finishReason = events
        .expand((event) => [event.payload['reason']])
        .whereType<String>()
        .firstOrNull;
    final response = await _rpc('pvp_commit_transition', {
      'p_match_id': before.id,
      'p_expected_revision': before.session.revision,
      'p_status': after.status,
      'p_engine_state': PvpCodec.encodeSession(after.session),
      'p_public_state': _publicProjection(after.session),
      'p_player_projections': after.projectionsByUser,
      'p_winner_id': winnerId,
      'p_finish_reason': finishReason,
      'p_command': {
        'actorUserId': command.actorUserId,
        'idempotencyKey': command.idempotencyKey,
        'type': command.commandType.name,
        'payload': command.payload,
        'result': command.result,
        'errorCode': command.response.errorCode,
        'response': command.response.toJson(),
      },
      'p_events': [
        for (final event in events) {'type': event.eventType, ...event.payload},
      ],
    });
    // The RPC returns the stored response. The service already holds the
    // typed response; decoding is intentionally only a protocol sanity check.
    if (response is Map && response['matchId'] != before.id) {
      throw const FormatException('transition response match mismatch');
    }

    // The commit RPC does not carry the clock, so it is written alongside.
    // A failure here must not undo an applied move: the worst case is a window
    // that keeps the previous deadline and expires a little late.
    try {
      await _request(
        'PATCH',
        '/pvp_matches',
        query: {'id': 'eq.${after.id}'},
        body: {
          'turn_deadline': after.turnDeadline?.toIso8601String(),
        },
      );
    } catch (error) {
      stderr.writeln('turn deadline not stored for ${after.id}: $error');
    }
  }

  @override
  Future<void> touchPlayer(String matchId, String userId) async {
    await _request(
      'PATCH',
      '/pvp_match_players',
      query: {'match_id': 'eq.$matchId', 'user_id': 'eq.$userId'},
      body: {
        'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        'connected_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> body) async {
    final response = await _request('POST', '/rpc/$name', body: body);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _request('GET', path, query: query);
    final decoded = jsonDecode(response.body);
    if (decoded is! List)
      throw const FormatException('Supabase response is not a list');
    return [
      for (final item in decoded)
        if (item is Map)
          Map<String, dynamic>.from(item)
        else
          throw const FormatException('Supabase row is not an object'),
    ];
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri =
        Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1$path')
            .replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll(_headers)
      ..body = body == null ? '' : jsonEncode(body);
    final response = await client.send(request).then(http.Response.fromStream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PvpRepositoryException(response.statusCode, response.body);
    }
    return response;
  }

  Map<String, String> get _headers => {
        'apikey': serviceKey,
        'Authorization': 'Bearer $serviceKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static PvpCommandResponse _responseFromJson(Map<String, dynamic> json) =>
      PvpCommandResponse(
        matchId: json['matchId'] as String,
        accepted: json['accepted'] as bool,
        duplicate: json['duplicate'] as bool? ?? false,
        revision: json['revision'] as int,
        status: json['status'] as String,
        projection: _map(json['projection']),
        events: [
          for (final event in (json['events'] as List? ?? const []))
            _map(event),
        ],
        errorCode: json['errorCode'] as String?,
        message: json['message'] as String?,
      );

  static Map<String, dynamic> _publicProjection(PvpSession session) {
    final projection = PvpCodec.encodeProjection(session, PlayerId.p1);
    final players = Map<String, dynamic>.from(projection['players'] as Map);
    for (final key in ['p1', 'p2']) {
      final player = Map<String, dynamic>.from(players[key] as Map)
        ..['hand'] = const <Map<String, dynamic>>[]
        ..remove('viewer');
      players[key] = player;
    }
    return {...projection, 'players': players};
  }
}
