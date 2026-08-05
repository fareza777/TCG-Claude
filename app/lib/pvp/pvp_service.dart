import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_models.dart';

/// Narrow boundary used by the controller. The real Supabase implementation
/// and deterministic test fakes both use the same contract.
abstract interface class PvpGateway {
  Future<PvpQueueResult> joinQueue(List<String> deckSnapshot);

  Future<void> leaveQueue();

  /// Public events newer than [afterSeq], oldest first.
  ///
  /// The projection says what the board looks like; these say what just
  /// happened, which is what the battle screen animates.
  Future<List<PvpMatchEvent>> eventsSince(String matchId, int afterSeq);

  /// The match this player is already in, or null.
  ///
  /// The server refuses to queue anyone holding a live match, so without this
  /// a player who closed the app mid-match is simply stuck: the lobby offers
  /// to find an opponent and the server answers "already in match".
  Future<String?> findActiveMatch();

  Future<PvpCommandResponse> sendCommand(String matchId, PvpCommand command);

  Future<PvpProjection> reconnect(String matchId);

  Stream<PvpProjection> watchMatch(String matchId, String userId);

  Stream<String> watchQueue(String userId);

  void dispose();
}

class PvpServiceException implements Exception {
  final String message;
  final String? code;

  const PvpServiceException(this.message, {this.code});

  @override
  String toString() => code == null ? message : '$code: $message';
}

/// Supabase Edge Function + Realtime adapter for online PvP.
class PvpService implements PvpGateway {
  PvpService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final _channels = <RealtimeChannel>[];
  final _controllers = <StreamController<dynamic>>[];

  @override
  Future<PvpQueueResult> joinQueue(List<String> deckSnapshot) async {
    final data = await _invoke('pvp-queue', {
      'action': 'join',
      'deckSnapshot': deckSnapshot,
    });
    return PvpQueueResult.fromJson(data);
  }

  @override
  Future<void> leaveQueue() async {
    await _invoke('pvp-queue', {'action': 'leave'});
  }

  @override
  Future<List<PvpMatchEvent>> eventsSince(String matchId, int afterSeq) async {
    // Row level security already limits this to matches the caller is in, and
    // public_payload never carries hidden state.
    final rows = await _client
        .from('pvp_events')
        .select('seq, event_type, public_payload')
        .eq('match_id', matchId)
        .gt('seq', afterSeq)
        .order('seq')
        .limit(50);
    return [for (final row in rows) PvpMatchEvent.fromRow(row)];
  }

  @override
  Future<String?> findActiveMatch() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Row level security already limits this to matches the caller is in.
    final rows = await _client
        .from('pvp_matches')
        .select('id')
        .inFilter('status', ['starting', 'active'])
        .order('created_at', ascending: false)
        .limit(1);

    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  @override
  Future<PvpCommandResponse> sendCommand(
    String matchId,
    PvpCommand command,
  ) async {
    final data = await _invoke('pvp-command', {
      'matchId': matchId,
      'command': command.toJson(),
    });
    return PvpCommandResponse.fromJson(data);
  }

  @override
  Future<PvpProjection> reconnect(String matchId) async {
    final data = await _invoke('pvp-command', {
      'action': 'reconnect',
      'matchId': matchId,
    });
    final projection = data['projection'];
    if (projection is! Map) {
      throw const PvpServiceException('The match projection is unavailable.');
    }
    return PvpProjection.fromJson(Map<String, dynamic>.from(projection));
  }

  @override
  Stream<PvpProjection> watchMatch(String matchId, String userId) {
    final controller = StreamController<PvpProjection>.broadcast();
    final channel = _client.channel('pvp-match:$matchId:$userId');

    // One command publishes more than one event -- a card play emits both
    // card_played and state_changed -- and each of those would otherwise pull
    // the whole projection back through the Edge Function, the Dart service
    // and several Postgres queries. Coalescing means a burst costs one
    // refresh, with a single follow-up if anything landed while it was in
    // flight, so nothing is missed and nothing is fetched twice.
    var refreshing = false;
    var refreshAgain = false;

    Future<void> refresh() async {
      if (refreshing) {
        refreshAgain = true;
        return;
      }
      refreshing = true;
      try {
        do {
          refreshAgain = false;
          controller.add(await reconnect(matchId));
        } while (refreshAgain);
      } catch (error, stack) {
        controller.addError(error, stack);
      } finally {
        refreshing = false;
      }
    }

    void refreshProjection(PostgresChangePayload _) => unawaited(refresh());

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pvp_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: refreshProjection,
        )
        // pvp_match_players is deliberately NOT watched. Reading a projection
        // stamps connected_at and last_heartbeat_at on that very table, so
        // refreshing on its changes fed itself: every read triggered a write
        // that triggered another read, a few times a second, until the match
        // screen stopped responding. pvp_events already fires for every
        // accepted command, which is the state the player actually needs.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pvp_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: matchId,
          ),
          callback: refreshProjection,
        )
        .subscribe();

    _channels.add(channel);
    _controllers.add(controller);
    controller.onCancel = () {
      _channels.remove(channel);
      _controllers.remove(controller);
      unawaited(channel.unsubscribe());
    };
    return controller.stream;
  }

  @override
  Stream<String> watchQueue(String userId) {
    final controller = StreamController<String>.broadcast();
    final channel = _client.channel('pvp-queue:$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pvp_match_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final matchId = payload.newRecord['match_id'];
            if (matchId is String && matchId.isNotEmpty) {
              controller.add(matchId);
            }
          },
        )
        .subscribe();

    _channels.add(channel);
    _controllers.add(controller);
    controller.onCancel = () {
      _channels.remove(channel);
      _controllers.remove(controller);
      unawaited(channel.unsubscribe());
    };
    return controller.stream;
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is! Map) {
        throw const PvpServiceException(
          'The PvP service returned invalid data.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on PvpServiceException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        final map = Map<String, dynamic>.from(details);
        throw PvpServiceException(
          (map['message'] as String?) ??
              (map['error'] as String?) ??
              'The PvP service rejected the request.',
          code: map['errorCode'] as String? ?? map['error'] as String?,
        );
      }
      throw PvpServiceException(
        error.reasonPhrase ?? 'The PvP service rejected the request.',
      );
    } catch (error) {
      throw PvpServiceException('PvP connection failed: $error');
    }
  }

  @override
  void dispose() {
    for (final channel in List<RealtimeChannel>.from(_channels)) {
      unawaited(channel.unsubscribe());
    }
    for (final controller in List<StreamController<dynamic>>.from(
      _controllers,
    )) {
      unawaited(controller.close());
    }
    _channels.clear();
    _controllers.clear();
  }
}
