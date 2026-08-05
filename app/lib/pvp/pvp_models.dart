import 'dart:math';

import 'package:shardfall_engine/shardfall_engine.dart';

/// Connection state shown by the PvP lobby and match screen.
enum PvpConnectionState {
  unavailable,
  idle,
  joining,
  queued,
  starting,
  reconnecting,
  active,
  finished,
  error,
}

class PvpCardView {
  final int instanceId;
  final String cardId;
  final String name;
  final CardType? type;
  final String subtype;
  final List<Dominion> dominions;
  final int might;
  final int guard;
  final bool exerted;
  final int damage;
  final int plusCounters;
  final bool summonedThisTurn;

  const PvpCardView({
    required this.instanceId,
    required this.cardId,
    required this.name,
    required this.type,
    required this.subtype,
    required this.dominions,
    required this.might,
    required this.guard,
    required this.exerted,
    required this.damage,
    required this.plusCounters,
    required this.summonedThisTurn,
  });

  factory PvpCardView.fromJson(Map<String, dynamic> json) => PvpCardView(
    instanceId: _asInt(json['instanceId'], 'card.instanceId'),
    cardId: _asString(json['cardId'], 'card.cardId'),
    name: _asString(json['name'], 'card.name'),
    type: _enumOrNull(CardType.values, json['type']),
    subtype: _asString(json['subtype'] ?? '', 'card.subtype'),
    dominions: [
      for (final value in _asList(json['dominions'] ?? const []))
        _enum(Dominion.values, value, 'card.dominion'),
    ],
    might: _asInt(json['might'] ?? 0, 'card.might'),
    guard: _asInt(json['guard'] ?? 0, 'card.guard'),
    exerted: _asBool(json['exerted'] ?? false, 'card.exerted'),
    damage: _asInt(json['damage'] ?? 0, 'card.damage'),
    plusCounters: _asInt(json['plusCounters'] ?? 0, 'card.plusCounters'),
    summonedThisTurn: _asBool(
      json['summonedThisTurn'] ?? false,
      'card.summonedThisTurn',
    ),
  );
}

class PvpPlayerView {
  final PlayerId id;
  final int health;
  final List<PvpCardView> hand;
  final int handCount;
  final int deckCount;
  final List<PvpCardView> arena;
  final int ruinsCount;
  final int voidCount;
  final Map<Dominion, int> aetherPool;
  final bool playedWellspringThisTurn;
  final bool usedAttuneThisTurn;

  const PvpPlayerView({
    required this.id,
    required this.health,
    required this.hand,
    required this.handCount,
    required this.deckCount,
    required this.arena,
    required this.ruinsCount,
    required this.voidCount,
    required this.aetherPool,
    required this.playedWellspringThisTurn,
    required this.usedAttuneThisTurn,
  });

  factory PvpPlayerView.fromJson(Map<String, dynamic> json) => PvpPlayerView(
    id: _enum(PlayerId.values, json['id'], 'player.id'),
    health: _asInt(json['health'], 'player.health'),
    hand: [
      for (final raw in _asList(json['hand'] ?? const []))
        PvpCardView.fromJson(_asMap(raw, 'player.hand.card')),
    ],
    handCount: _asInt(json['handCount'], 'player.handCount'),
    deckCount: _asInt(json['deckCount'], 'player.deckCount'),
    arena: [
      for (final raw in _asList(json['arena'] ?? const []))
        PvpCardView.fromJson(_asMap(raw, 'player.arena.card')),
    ],
    ruinsCount: _asInt(json['ruinsCount'] ?? 0, 'player.ruinsCount'),
    voidCount: _asInt(json['voidCount'] ?? 0, 'player.voidCount'),
    aetherPool: {
      for (final entry in _asMap(
        json['aetherPool'] ?? const {},
        'aether',
      ).entries)
        _enum(Dominion.values, entry.key, 'aether.dominion'): _asInt(
          entry.value,
          'aether.value',
        ),
    },
    playedWellspringThisTurn: _asBool(
      json['playedWellspringThisTurn'] ?? false,
      'player.playedWellspringThisTurn',
    ),
    usedAttuneThisTurn: _asBool(
      json['usedAttuneThisTurn'] ?? false,
      'player.usedAttuneThisTurn',
    ),
  );
}

class PvpProjection {
  final int version;
  final PlayerId viewer;
  final PlayerId activePlayer;
  final Phase phase;
  final int turnNumber;
  final PlayerId? winner;
  final int chainCount;
  final PvpStage stage;
  final PlayerId priority;
  final List<int> pendingAttackers;
  final int revision;
  final PvpPlayerView self;
  final PvpPlayerView opponent;

  /// When the player who owes the current decision runs out of time.
  ///
  /// Decided and enforced by the server; the client only draws it. A locally
  /// invented clock would disagree with the side doing the enforcing.
  final DateTime? deadlineAt;

  const PvpProjection({
    required this.version,
    required this.viewer,
    required this.activePlayer,
    required this.phase,
    required this.turnNumber,
    required this.winner,
    required this.chainCount,
    required this.stage,
    required this.priority,
    required this.pendingAttackers,
    required this.revision,
    required this.self,
    required this.opponent,
    this.deadlineAt,
  });

  factory PvpProjection.fromJson(Map<String, dynamic> json) {
    final players = _asMap(json['players'], 'players');
    final p1 = PvpPlayerView.fromJson(_asMap(players['p1'], 'players.p1'));
    final p2 = PvpPlayerView.fromJson(_asMap(players['p2'], 'players.p2'));
    final viewer = _enum(
      PlayerId.values,
      (_asMap(players['p1'], 'players.p1')['viewer'] ??
          _asMap(players['p2'], 'players.p2')['viewer']),
      'players.viewer',
    );
    final winner = json['winner'];
    return PvpProjection(
      deadlineAt: DateTime.tryParse(json['deadlineAt'] as String? ?? '')?.toUtc(),
      version: _asInt(json['version'], 'version'),
      viewer: viewer,
      activePlayer: _enum(
        PlayerId.values,
        json['activePlayer'],
        'activePlayer',
      ),
      phase: _enum(Phase.values, json['phase'], 'phase'),
      turnNumber: _asInt(json['turnNumber'], 'turnNumber'),
      winner: winner == null ? null : _enum(PlayerId.values, winner, 'winner'),
      chainCount: _asInt(json['chainCount'] ?? 0, 'chainCount'),
      stage: _enum(PvpStage.values, json['stage'], 'stage'),
      priority: _enum(PlayerId.values, json['priority'], 'priority'),
      pendingAttackers: [
        for (final value in _asList(json['pendingAttackers'] ?? const []))
          _asInt(value, 'pendingAttackers.item'),
      ],
      revision: _asInt(json['revision'], 'revision'),
      self: viewer == PlayerId.p1 ? p1 : p2,
      opponent: viewer == PlayerId.p1 ? p2 : p1,
    );
  }

  bool get isMyTurn => activePlayer == viewer;
  bool get hasPriority => priority == viewer;
  bool get isFinished => stage == PvpStage.finished;
}

class PvpQueueResult {
  final String status;
  final String? matchId;
  final String? message;

  const PvpQueueResult({required this.status, this.matchId, this.message});

  factory PvpQueueResult.fromJson(Map<String, dynamic> json) => PvpQueueResult(
    status: _asString(json['status'], 'queue.status'),
    matchId: json['matchId'] as String?,
    message: json['message'] as String?,
  );

  bool get matched => status == 'matched' && matchId != null;
}

class PvpCommandResponse {
  final bool accepted;
  final bool duplicate;
  final String status;
  final int revision;
  final PvpProjection? projection;
  final String? errorCode;
  final String? message;

  const PvpCommandResponse({
    required this.accepted,
    required this.status,
    this.duplicate = false,
    this.revision = 0,
    this.projection,
    this.errorCode,
    this.message,
  });

  factory PvpCommandResponse.fromJson(Map<String, dynamic> json) =>
      PvpCommandResponse(
        accepted: json['accepted'] == true,
        duplicate: json['duplicate'] == true,
        status: (json['status'] as String?) ?? 'unknown',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        projection: json['projection'] is Map
            ? PvpProjection.fromJson(_asMap(json['projection'], 'projection'))
            : null,
        errorCode: json['errorCode'] as String?,
        message: json['message'] as String?,
      );
}

String newPvpIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object');
  return Map<String, dynamic>.from(value);
}

List<Object?> _asList(Object? value) {
  if (value is! List) throw const FormatException('Expected an array');
  return value;
}

String _asString(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return value;
}

int _asInt(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

bool _asBool(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

T _enum<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return _enumOrNull(values, value) ??
      (throw FormatException('Unknown $field: $value'));
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? value) {
  if (value is! String) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}

/// One public event from the match stream, used to drive battle animations.
///
/// The board can be rebuilt from a projection alone, but the duel screen also
/// animates: a lunge on an attack, a sound on a card hitting the table. Those
/// cues come from events, so PvP reads them the same way the single-player
/// duel emits them.
class PvpMatchEvent {
  final int seq;
  final String type;
  final Map<String, dynamic> payload;

  const PvpMatchEvent({
    required this.seq,
    required this.type,
    this.payload = const {},
  });

  factory PvpMatchEvent.fromRow(Map<String, dynamic> row) => PvpMatchEvent(
        seq: _asInt(row['seq'], 'seq'),
        type: (row['event_type'] ?? 'state_changed').toString(),
        payload: row['public_payload'] is Map
            ? _asMap(row['public_payload'], 'public_payload')
            : const {},
      );
}
