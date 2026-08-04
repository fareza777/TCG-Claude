import '../effects/interpreter.dart';
import '../model/enums.dart';
import '../model/game_state.dart';
import '../data/library.dart';
import 'pvp_session.dart';

/// Versioned transport codec for the authoritative PvP session.
///
/// The full session codec is server-only persistence data. The projection
/// codec is safe to send to one player and deliberately redacts hidden zones.
abstract final class PvpCodec {
  static const version = 1;

  static Map<String, dynamic> encodeSession(PvpSession session) => {
        'version': version,
        'game': _encodeGame(session.game),
        'stage': session.stage.name,
        'ready': _encodeBoolMap(session.ready),
        'mulliganUsed': _encodeBoolMap(session.mulliganUsed),
        'priority': session.priority.name,
        'passCount': session.passCount,
        'resumeStage': session.resumeStage.name,
        'pendingAttackers': session.pendingAttackers,
        'revision': session.revision,
      };

  static PvpSession decodeSession(
    Map<String, dynamic> json,
    CardLibrary library,
  ) {
    final versionValue = json['version'];
    if (versionValue != version) {
      throw FormatException('Unsupported PvP session version: $versionValue');
    }
    final game = _decodeGame(_asMap(json['game'], 'game'), library);
    return PvpSession(
      game: game,
      stage: _enumByName(PvpStage.values, json['stage'], 'stage'),
      ready: _decodeBoolMap(json['ready'], 'ready'),
      mulliganUsed: _decodeBoolMap(json['mulliganUsed'], 'mulliganUsed'),
      priority: _enumByName(PlayerId.values, json['priority'], 'priority'),
      passCount: _asInt(json['passCount'], 'passCount'),
      resumeStage:
          _enumByName(PvpStage.values, json['resumeStage'], 'resumeStage'),
      pendingAttackers:
          _asIntList(json['pendingAttackers'], 'pendingAttackers'),
      revision: _asInt(json['revision'], 'revision'),
    );
  }

  /// Build a player-safe view. Opponent hands and all deck ordering are
  /// represented only by counts. The RNG seed and private Chain choices are
  /// never included.
  static Map<String, dynamic> encodeProjection(
    PvpSession session,
    PlayerId viewer,
  ) {
    final opponent = viewer.opponent;
    return {
      'version': version,
      'activePlayer': session.game.activePlayer.name,
      'phase': session.game.phase.name,
      'turnNumber': session.game.turnNumber,
      'winner': session.game.winner?.name,
      'chainCount': session.game.chain.length,
      'stage': session.stage.name,
      'priority': session.priority.name,
      'pendingAttackers': session.pendingAttackers,
      'revision': session.revision,
      'players': {
        'p1': _encodePlayerProjection(
          session.game.p1,
          viewer: viewer,
          isOpponent: PlayerId.p1 == opponent,
        ),
        'p2': _encodePlayerProjection(
          session.game.p2,
          viewer: viewer,
          isOpponent: PlayerId.p2 == opponent,
        ),
      },
    };
  }

  static Map<String, dynamic> _encodeGame(GameState game) => {
        'p1': _encodePlayer(game.p1),
        'p2': _encodePlayer(game.p2),
        'activePlayer': game.activePlayer.name,
        'phase': game.phase.name,
        'turnNumber': game.turnNumber,
        'nextInstanceId': game.nextInstanceId,
        'rngSeed': game.rngSeed,
        'winner': game.winner?.name,
        'chain': [for (final item in game.chain) _encodeChainItem(item)],
        'firstPlayer': game.firstPlayer.name,
      };

  static GameState _decodeGame(
    Map<String, dynamic> json,
    CardLibrary library,
  ) {
    final winnerName = json['winner'];
    if (winnerName != null && winnerName is! String) {
      throw const FormatException('winner must be a player or null');
    }
    return GameState(
      p1: _decodePlayer(_asMap(json['p1'], 'p1'), library),
      p2: _decodePlayer(_asMap(json['p2'], 'p2'), library),
      activePlayer:
          _enumByName(PlayerId.values, json['activePlayer'], 'activePlayer'),
      phase: _enumByName(Phase.values, json['phase'], 'phase'),
      turnNumber: _asInt(json['turnNumber'], 'turnNumber'),
      nextInstanceId: _asInt(json['nextInstanceId'], 'nextInstanceId'),
      rngSeed: _asInt(json['rngSeed'], 'rngSeed'),
      winner: winnerName == null
          ? null
          : _enumByName(PlayerId.values, winnerName, 'winner'),
      chain: [
        for (final raw in _asList(json['chain'], 'chain'))
          _decodeChainItem(_asMap(raw, 'chain item'), library),
      ],
      firstPlayer:
          _enumByName(PlayerId.values, json['firstPlayer'], 'firstPlayer'),
    );
  }

  static Map<String, dynamic> _encodePlayer(PlayerState player) => {
        'id': player.id.name,
        'health': player.health,
        'deck': [for (final card in player.deck) _encodeCardInstance(card)],
        'hand': [for (final card in player.hand) _encodeCardInstance(card)],
        'arena': [for (final card in player.arena) _encodeCardInstance(card)],
        'ruins': [for (final card in player.ruins) _encodeCardInstance(card)],
        'voidZone': [
          for (final card in player.voidZone) _encodeCardInstance(card),
        ],
        'aetherPool': {
          for (final entry in player.aetherPool.entries)
            entry.key.name: entry.value,
        },
        'playedWellspringThisTurn': player.playedWellspringThisTurn,
        'usedAttuneThisTurn': player.usedAttuneThisTurn,
      };

  static PlayerState _decodePlayer(
    Map<String, dynamic> json,
    CardLibrary library,
  ) {
    final id = _enumByName(PlayerId.values, json['id'], 'player id');
    return PlayerState(
      id: id,
      health: _asInt(json['health'], 'health'),
      deck: _decodeCards(json['deck'], library, 'deck'),
      hand: _decodeCards(json['hand'], library, 'hand'),
      arena: _decodeCards(json['arena'], library, 'arena'),
      ruins: _decodeCards(json['ruins'], library, 'ruins'),
      voidZone: _decodeCards(json['voidZone'], library, 'voidZone'),
      aetherPool: _decodeAether(json['aetherPool']),
      playedWellspringThisTurn:
          _asBool(json['playedWellspringThisTurn'], 'playedWellspringThisTurn'),
      usedAttuneThisTurn:
          _asBool(json['usedAttuneThisTurn'], 'usedAttuneThisTurn'),
    );
  }

  static List<CardInstance> _decodeCards(
    Object? value,
    CardLibrary library,
    String field,
  ) =>
      [
        for (final raw in _asList(value, field))
          _decodeCardInstance(_asMap(raw, field), library),
      ];

  static Map<String, dynamic> _encodeCardInstance(CardInstance card) => {
        'instanceId': card.instanceId,
        'cardId': card.def.id,
        'owner': card.owner.name,
        'exerted': card.exerted,
        'damage': card.damage,
        'plusCounters': card.plusCounters,
        'summonedThisTurn': card.summonedThisTurn,
        'tempMight': card.tempMight,
        'tempGuard': card.tempGuard,
        'tempKeywords': [for (final k in card.tempKeywords) k.name],
      };

  static CardInstance _decodeCardInstance(
    Map<String, dynamic> json,
    CardLibrary library,
  ) {
    final keywords = _asList(json['tempKeywords'], 'tempKeywords');
    return CardInstance(
      instanceId: _asInt(json['instanceId'], 'instanceId'),
      def: library.card(_asString(json['cardId'], 'cardId')),
      owner: _enumByName(PlayerId.values, json['owner'], 'owner'),
      exerted: _asBool(json['exerted'], 'exerted'),
      damage: _asInt(json['damage'], 'damage'),
      plusCounters: _asInt(json['plusCounters'], 'plusCounters'),
      summonedThisTurn: _asBool(json['summonedThisTurn'], 'summonedThisTurn'),
      tempMight: _asInt(json['tempMight'], 'tempMight'),
      tempGuard: _asInt(json['tempGuard'], 'tempGuard'),
      tempKeywords: {
        for (final raw in keywords)
          _enumByName(Keyword.values, raw, 'tempKeyword'),
      },
    );
  }

  static Map<String, dynamic> _encodeChainItem(ChainItem item) => {
        'source': _encodeCardInstance(item.source),
        'controller': item.controller.name,
        'triggerBlock': _jsonValue(item.triggerBlock),
        'chosenTargets': [
          for (final target in item.chosenTargets)
            _encodeTarget(target as EffectTarget),
        ],
        'uncounterable': item.uncounterable,
        'countered': item.countered,
      };

  static ChainItem _decodeChainItem(
    Map<String, dynamic> json,
    CardLibrary library,
  ) =>
      ChainItem(
        source: _decodeCardInstance(_asMap(json['source'], 'source'), library),
        controller:
            _enumByName(PlayerId.values, json['controller'], 'controller'),
        triggerBlock: _asMap(json['triggerBlock'], 'triggerBlock'),
        chosenTargets: [
          for (final raw in _asList(json['chosenTargets'], 'chosenTargets'))
            _decodeTarget(_asMap(raw, 'target')),
        ],
        uncounterable: _asBool(json['uncounterable'], 'uncounterable'),
        countered: _asBool(json['countered'], 'countered'),
      );

  static Map<String, dynamic> _encodeTarget(EffectTarget target) {
    if (target.instanceId != null) {
      return {'kind': 'unit', 'instanceId': target.instanceId};
    }
    return {'kind': 'player', 'playerId': target.playerId?.name};
  }

  static EffectTarget _decodeTarget(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'unit':
        return EffectTarget.unit(
            _asInt(json['instanceId'], 'target instanceId'));
      case 'player':
        final player = json['playerId'];
        return EffectTarget.player(
          player == null
              ? null
              : _enumByName(PlayerId.values, player, 'target playerId'),
        );
      default:
        throw const FormatException('Unknown EffectTarget kind');
    }
  }

  static Map<String, dynamic> _encodePlayerProjection(
    PlayerState player, {
    required PlayerId viewer,
    required bool isOpponent,
  }) {
    final hand = isOpponent
        ? const <Map<String, dynamic>>[]
        : [for (final card in player.hand) _encodeCardView(card)];
    return {
      'id': player.id.name,
      'health': player.health,
      'hand': hand,
      'handCount': player.hand.length,
      'deck': const <Map<String, dynamic>>[],
      'deckCount': player.deck.length,
      'arena': [for (final card in player.arena) _encodeCardView(card)],
      'ruins': [for (final card in player.ruins) _encodeCardView(card)],
      'ruinsCount': player.ruins.length,
      'voidCount': player.voidZone.length,
      'aetherPool': {
        for (final entry in player.aetherPool.entries)
          entry.key.name: entry.value,
      },
      'playedWellspringThisTurn': player.playedWellspringThisTurn,
      'usedAttuneThisTurn': player.usedAttuneThisTurn,
      'viewer': viewer.name,
    };
  }

  static Map<String, dynamic> _encodeCardView(CardInstance card) => {
        'instanceId': card.instanceId,
        'cardId': card.def.id,
        'name': card.def.name,
        'type': card.def.type.name,
        'subtype': card.def.subtype,
        'dominions': [for (final d in card.def.dominions) d.name],
        'costDominion': {
          for (final entry in card.def.costDominion.entries)
            entry.key.name: entry.value,
        },
        'costGeneric': card.def.costGeneric,
        'might': card.might,
        'guard': card.guard,
        'keywords': [for (final k in card.keywords) k.name],
        'aegisValue': card.def.aegisValue,
        'exerted': card.exerted,
        'damage': card.damage,
        'plusCounters': card.plusCounters,
        'summonedThisTurn': card.summonedThisTurn,
      };

  static Map<String, bool> _encodeBoolMap(Map<PlayerId, bool> values) => {
        for (final id in PlayerId.values) id.name: values[id] ?? false,
      };

  static Map<PlayerId, bool> _decodeBoolMap(Object? value, String field) {
    final map = _asMap(value, field);
    return {
      for (final id in PlayerId.values)
        id: _asBool(map[id.name] ?? false, '$field.${id.name}'),
    };
  }

  static Map<Dominion, int> _decodeAether(Object? value) {
    final map = _asMap(value, 'aetherPool');
    return {
      for (final entry in map.entries)
        _enumByName(Dominion.values, entry.key, 'aether key'):
            _asInt(entry.value, 'aether value'),
    };
  }

  static dynamic _jsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) return [for (final item in value) _jsonValue(item)];
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonValue(entry.value),
      };
    }
    throw FormatException('Unsupported JSON value: ${value.runtimeType}');
  }

  static T _enumByName<T extends Enum>(
      List<T> values, Object? value, String field) {
    if (value is! String) throw FormatException('$field must be a string');
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown $field: $value');
    }
  }

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object');
    return Map<String, dynamic>.from(value);
  }

  static List<Object?> _asList(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be an array');
    return value;
  }

  static String _asString(Object? value, String field) {
    if (value is! String) throw FormatException('$field must be a string');
    return value;
  }

  static int _asInt(Object? value, String field) {
    if (value is! int) throw FormatException('$field must be an integer');
    return value;
  }

  static bool _asBool(Object? value, String field) {
    if (value is! bool) throw FormatException('$field must be a boolean');
    return value;
  }

  static List<int> _asIntList(Object? value, String field) => [
        for (final item in _asList(value, field)) _asInt(item, '$field item'),
      ];
}
