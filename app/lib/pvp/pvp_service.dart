import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_models.dart';

/// Narrow boundary used by the controller. The real Supabase implementation
/// and deterministic test fakes both use the same contract.
abstract interface class PvpGateway {
  Future<PvpQueueResult> joinQueue(List<String> deckSnapshot);

  Future<void> leaveQueue();

  /// The match this player is already in, or null.
  ///
  /// The server refuses to queue anyone holding a live match, so without this
  /// a player who closed the app mid-match is simply stuck: the lobby offers
  /// to find an opponent and the server answers "already in match".
  Future<String?> findActiveMatch();

  Future<PvpCommandResponse> sendCommand(String matchId, PvpCommand command);

  Future<PvpProjection> reconnect(String matchId);

  Stream<PvpProjection> watchMatch(
    String matchId,
    String userId, {
    int Function()? appliedRevision,
  });

  /// Live match events, oldest first, as they are committed.
  ///
  /// The projection says what the board looks like; these say what just
  /// happened, which is what the battle screen animates.
  Stream<PvpMatchEvent> watchEvents(String matchId);

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
  Stream<PvpProjection> watchMatch(
    String matchId,
    String userId, {
    int Function()? appliedRevision,
  }) {
    final controller = StreamController<PvpProjection>.broadcast();
    final channel = _client.channel('pvp-match:$matchId:$userId');
    var lastDelivered = -1;

    void deliver(PvpProjection projection) {
      // Heartbeats and presence stamps rewrite the row without moving the
      // game; a revision this client has already shown is not news.
      if (projection.revision <= lastDelivered) return;
      final seen = appliedRevision?.call();
      if (seen != null && projection.revision <= seen) return;
      lastDelivered = projection.revision;
      controller.add(projection);
    }

    // The player's own match row carries their private projection, so the
    // board arrives inside the realtime payload itself. The old flow threw
    // that away and refetched the projection through the Edge Function and
    // the Dart service on every event -- the better part of a second between
    // the opponent moving and the board changing here. Row level security
    // limits the row to the owner, so the opponent's hidden state never
    // reaches this channel.
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pvp_match_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record['match_id'] != matchId) return;
            final raw = record['private_state'];
            if (raw is! Map) return;
            try {
              deliver(PvpProjection.fromJson(Map<String, dynamic>.from(raw)));
            } on FormatException {
              // A projection that cannot be read is retried as a full
              // reconnect below rather than dropping the match.
              unawaited(reconnect(matchId).then(deliver, onError: (_) {}));
            }
          },
        )
        .subscribe((status, [error]) {
          if (status != RealtimeSubscribeStatus.subscribed) return;
          // Anything committed before the subscription went live would
          // otherwise be invisible until the next move. One catch-up read
          // closes that gap; staleness is filtered by deliver().
          unawaited(
            reconnect(matchId).then(deliver, onError: (Object e, StackTrace s) {
              controller.addError(e, s);
            }),
          );
        });

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
  Stream<PvpMatchEvent> watchEvents(String matchId) {
    final controller = StreamController<PvpMatchEvent>.broadcast();
    final channel = _client.channel('pvp-events:$matchId');

    // Events that arrive before the high-water mark is known are buffered,
    // then replayed in order once it is. The mark itself is read after the
    // subscription is live, so history is skipped without losing anything
    // committed in between.
    var highWater = -1;
    var ready = false;
    final buffer = <PvpMatchEvent>[];

    void flush() {
      ready = true;
      buffer.sort((a, b) => a.seq.compareTo(b.seq));
      for (final event in buffer) {
        if (event.seq > highWater) {
          highWater = event.seq;
          controller.add(event);
        }
      }
      buffer.clear();
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pvp_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) {
            final event = PvpMatchEvent.fromRow(payload.newRecord);
            if (!ready) {
              buffer.add(event);
              return;
            }
            if (event.seq <= highWater) return;
            highWater = event.seq;
            controller.add(event);
          },
        )
        .subscribe((status, [error]) {
          if (status != RealtimeSubscribeStatus.subscribed) return;
          unawaited(() async {
            try {
              highWater = await _latestEventSeq(matchId);
            } catch (_) {
              // Animation cues are decoration; if the mark cannot be read,
              // play whatever the buffer holds rather than nothing at all.
            }
            flush();
          }());
        });

    _channels.add(channel);
    _controllers.add(controller);
    controller.onCancel = () {
      _channels.remove(channel);
      _controllers.remove(controller);
      unawaited(channel.unsubscribe());
    };
    return controller.stream;
  }

  /// The newest event sequence the match has committed, for skipping history
  /// when a subscription starts mid-match.
  Future<int> _latestEventSeq(String matchId) async {
    final rows = await _client
        .from('pvp_events')
        .select('seq')
        .eq('match_id', matchId)
        .order('seq', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['seq'] as num).toInt();
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
