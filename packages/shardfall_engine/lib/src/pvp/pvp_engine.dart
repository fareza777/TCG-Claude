import '../effects/interpreter.dart';
import '../model/card_def.dart';
import '../model/enums.dart';
import '../model/game_state.dart';
import '../rules/chain.dart';
import '../rules/combat.dart';
import '../rules/game.dart';
import 'pvp_command.dart';
import 'pvp_session.dart';

class PvpEvent {
  final String type;
  final Map<String, dynamic> payload;

  const PvpEvent(this.type, {this.payload = const {}});
}

class PvpRuleError {
  final String code;
  final String message;

  const PvpRuleError(this.code, this.message);
}

class PvpCommandResult {
  final PvpSession session;
  final List<PvpEvent> events;
  final PvpRuleError? error;

  const PvpCommandResult({
    required this.session,
    this.events = const [],
    this.error,
  });

  bool get accepted => error == null;
}

/// Server-side command adapter. It owns online protocol state, while all card
/// math remains in the existing pure Game/Chain/Combat rules.
abstract final class PvpEngine {
  static PvpSession create({
    required List<CardDef> deckP1,
    required List<CardDef> deckP2,
    required int seed,
    PlayerId firstPlayer = PlayerId.p1,
  }) {
    _requireDeck(deckP1, 'p1');
    _requireDeck(deckP2, 'p2');
    final game = Game.create(
      deckP1: deckP1,
      deckP2: deckP2,
      seed: seed,
      firstPlayer: firstPlayer,
    );
    return PvpSession(
      game: game,
      stage: PvpStage.waitingForReady,
      ready: const {PlayerId.p1: false, PlayerId.p2: false},
      mulliganUsed: const {PlayerId.p1: false, PlayerId.p2: false},
      priority: firstPlayer,
      passCount: 0,
      resumeStage: PvpStage.main,
      pendingAttackers: const [],
      revision: 0,
    );
  }

  static PvpCommandResult apply(
    PvpSession session,
    PlayerId actor,
    PvpCommand command,
  ) {
    if (command.idempotencyKey.trim().isEmpty) {
      return _reject(
          session, 'invalid_command', 'Idempotency key is required.');
    }
    if (command.revision != session.revision) {
      return _reject(
        session,
        'stale_revision',
        'The command was based on an old match revision.',
      );
    }
    if (session.stage == PvpStage.finished &&
        command.type != PvpCommandType.heartbeat) {
      return _reject(
          session, 'match_finished', 'The match is already finished.');
    }

    try {
      final result = switch (command.type) {
        PvpCommandType.ready => _ready(session, actor),
        PvpCommandType.redraw => _redraw(session, actor),
        PvpCommandType.nextPhase => _nextPhase(session, actor),
        PvpCommandType.playWellspring =>
          _playWellspring(session, actor, command.payload),
        PvpCommandType.exertForAether =>
          _exertForAether(session, actor, command.payload),
        PvpCommandType.playUnit => _playUnit(session, actor, command.payload),
        PvpCommandType.cast => _cast(session, actor, command.payload),
        PvpCommandType.declareAttackers =>
          _declareAttackers(session, actor, command.payload),
        PvpCommandType.declareBlocks =>
          _declareBlocks(session, actor, command.payload),
        PvpCommandType.passPriority => _passPriority(session, actor),
        PvpCommandType.concede => _concede(session, actor),
        // Presence only: no event, so it does not wake both clients into a
        // full projection refetch every 20 seconds for no state change.
        PvpCommandType.heartbeat => _Transition(
            session: session,
            incrementsRevision: false,
          ),
      };
      if (result.session == null) {
        return const PvpCommandResult(
          session: _invalidSession,
          error:
              PvpRuleError('internal_error', 'Missing PvP transition state.'),
        );
      }
      final next = result.incrementsRevision
          ? result.session!.copyWith(revision: session.revision + 1)
          : result.session!;
      return PvpCommandResult(
        session: next,
        events: [
          if (result.event != null) result.event!,
          if (result.incrementsRevision)
            PvpEvent('state_changed', payload: {
              'command': command.type.name,
              'revision': next.revision,
            }),
        ],
      );
    } on FormatException catch (error) {
      return _reject(session, 'invalid_payload', error.message);
    } on StateError catch (error) {
      final message = _stateErrorMessage(error);
      return _reject(session, _stateErrorCode(message), message);
    } on ArgumentError catch (error) {
      return _reject(session, 'invalid_payload', error.message.toString());
    }
  }

  static const _invalidSession = PvpSession(
    game: GameState(
      p1: PlayerState(id: PlayerId.p1),
      p2: PlayerState(id: PlayerId.p2),
      rngSeed: 0,
    ),
    stage: PvpStage.finished,
    ready: const {PlayerId.p1: false, PlayerId.p2: false},
    mulliganUsed: const {PlayerId.p1: false, PlayerId.p2: false},
    priority: PlayerId.p1,
    passCount: 0,
    resumeStage: PvpStage.main,
    pendingAttackers: const [],
    revision: 0,
  );

  static _Transition _ready(PvpSession session, PlayerId actor) {
    if (session.stage != PvpStage.waitingForReady &&
        session.stage != PvpStage.mulligan) {
      throw StateError('Ready is not available now');
    }
    if (session.isReady(actor)) throw StateError('Player is already ready');
    final ready = Map<PlayerId, bool>.from(session.ready)..[actor] = true;
    var next = session.copyWith(ready: ready);
    if (ready.values.every((value) => value)) {
      if (session.stage == PvpStage.waitingForReady) {
        next = next.copyWith(
          stage: PvpStage.mulligan,
          ready: const {PlayerId.p1: false, PlayerId.p2: false},
        );
        return _Transition(
          session: next,
          event: const PvpEvent('mulligan_started'),
        );
      }
      next = next.copyWith(
        stage: PvpStage.main,
        priority: next.game.activePlayer,
      );
      return _Transition(
        session: next,
        event: const PvpEvent('match_started'),
      );
    }
    return _Transition(session: next, event: const PvpEvent('player_ready'));
  }

  static _Transition _redraw(PvpSession session, PlayerId actor) {
    if (session.stage != PvpStage.mulligan) {
      throw StateError('Redraw is only available during mulligan');
    }
    if (session.usedMulligan(actor)) {
      throw StateError('Mulligan already used');
    }
    final used = Map<PlayerId, bool>.from(session.mulliganUsed)..[actor] = true;
    return _Transition(
      session: session.copyWith(
        game: Game.redraw(session.game, actor),
        mulliganUsed: used,
      ),
      event: PvpEvent('redraw', payload: {'player': actor.name}),
    );
  }

  static _Transition _nextPhase(PvpSession session, PlayerId actor) {
    if (session.stage != PvpStage.main) {
      throw StateError('Phase cannot advance now');
    }
    _requireActivePlayer(session, actor);
    if (session.game.chain.isNotEmpty) {
      throw StateError('The Chain must be empty');
    }
    var nextGame = Game.nextPhase(session.game);

    // refresh, draw and end carry no player decision. Parking the session on
    // one of them still reported PvpStage.main, so the client offered main
    // actions that _requireMainActor then rejected with "Main action is not
    // legal in this phase" -- the player could see their hand and tap it, and
    // nothing happened. Run those phases through, exactly as the single-player
    // controller does. The bound is a guard against a future rules change
    // making this walk non-terminating on the server.
    for (var guard = 0;
        guard < 8 &&
            nextGame.winner == null &&
            !_isActionablePhase(nextGame.phase);
        guard++) {
      nextGame = Game.nextPhase(nextGame);
    }

    final stage = nextGame.phase == Phase.combat
        ? PvpStage.attackDeclaration
        : PvpStage.main;
    final next = session.copyWith(
      game: nextGame,
      stage: nextGame.winner == null ? stage : PvpStage.finished,
      priority: nextGame.activePlayer,
      pendingAttackers: const [],
    );
    return _Transition(
      session: next,
      event: PvpEvent('phase_changed', payload: {
        'phase': nextGame.phase.name,
        'activePlayer': nextGame.activePlayer.name,
      }),
    );
  }

  static _Transition _playWellspring(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    _requireMainActor(session, actor);
    final id = _payloadInt(payload, 'instanceId');
    return _Transition(
      session: session.copyWith(
        game: Game.playWellspring(session.game, actor, id),
      ),
      event: PvpEvent('card_played', payload: {'instanceId': id}),
    );
  }

  static _Transition _exertForAether(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    _requireMainActor(session, actor);
    final id = _payloadInt(payload, 'instanceId');
    return _Transition(
      session: session.copyWith(
        game: Game.exertForAether(session.game, actor, id),
      ),
      event: PvpEvent('aether_gained', payload: {'instanceId': id}),
    );
  }

  static CardInstance _handCard(PvpSession session, PlayerId actor, int id) {
    final card = session.game
        .player(actor)
        .hand
        .where((c) => c.instanceId == id)
        .firstOrNull;
    if (card == null) throw StateError('Card is not in hand');
    return card;
  }

  /// Exerts Wellsprings until [def] can be paid for.
  ///
  /// The single-player controller does this silently before every play, so the
  /// client used to imitate it by sending one exertForAether command per
  /// Wellspring. Online that turned playing a single card into three or four
  /// network round trips, which is what made PvP feel sluggish. Doing it here
  /// makes a play one command again, and keeps the rule identical in both
  /// modes. If nothing is left to tap, the play itself refuses, so this never
  /// invents Aether.
  static GameState _raiseAether(GameState game, PlayerId actor, CardDef def) {
    var state = game;
    for (var guard = 0; guard < 30; guard++) {
      try {
        Game.payCost(def, state.player(actor).aetherPool);
        return state;
      } on StateError {
        final ready = state
            .player(actor)
            .arena
            .where((c) => c.def.type == CardType.wellspring && !c.exerted)
            .firstOrNull;
        if (ready == null) return state;
        state = Game.exertForAether(state, actor, ready.instanceId);
      }
    }
    return state;
  }

  static _Transition _playUnit(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    _requireMainActor(session, actor);
    final id = _payloadInt(payload, 'instanceId');
    final funded = _raiseAether(
      session.game,
      actor,
      _handCard(session, actor, id).def,
    );
    return _Transition(
      session: session.copyWith(
        game: Game.playUnit(
          funded,
          actor,
          id,
          chosen: _targets(payload),
        ),
      ),
      event: PvpEvent('card_played', payload: {'instanceId': id}),
    );
  }

  static _Transition _cast(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    if (session.stage != PvpStage.main &&
        session.stage != PvpStage.chainPriority) {
      throw StateError('Casting is not available now');
    }
    if (session.stage == PvpStage.main) {
      _requireMainActor(session, actor);
    } else if (actor != session.priority) {
      throw StateError('Only the priority player may respond');
    }
    final id = _payloadInt(payload, 'instanceId');
    final game = Chain.cast(
      _raiseAether(session.game, actor, _handCard(session, actor, id).def),
      actor,
      id,
      targets: _targets(payload),
    );
    return _Transition(
      session: session.copyWith(
        game: game,
        stage: PvpStage.chainPriority,
        priority: actor.opponent,
        passCount: 0,
        resumeStage: session.stage == PvpStage.main
            ? PvpStage.main
            : session.resumeStage,
      ),
      event: PvpEvent('chain_cast', payload: {'instanceId': id}),
    );
  }

  static _Transition _declareAttackers(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    if (session.stage != PvpStage.attackDeclaration) {
      throw StateError('Attackers cannot be declared now');
    }
    _requireActivePlayer(session, actor);
    final ids = _payloadIntList(payload, 'attackerIds');
    final game = Combat.declareAttackers(session.game, actor, ids);
    if (game.winner != null || ids.isEmpty) {
      final nextGame = game.winner == null ? Game.nextPhase(game) : game;
      return _Transition(
        session: session.copyWith(
          game: nextGame,
          stage: nextGame.winner == null ? PvpStage.main : PvpStage.finished,
          priority: nextGame.activePlayer,
          pendingAttackers: const [],
        ),
        event: const PvpEvent('attack_resolved'),
      );
    }
    return _Transition(
      session: session.copyWith(
        game: game,
        stage: PvpStage.blockDeclaration,
        priority: actor.opponent,
        pendingAttackers: ids,
      ),
      event: PvpEvent('attack_declared', payload: {'attackerIds': ids}),
    );
  }

  static _Transition _declareBlocks(
    PvpSession session,
    PlayerId actor,
    Map<String, dynamic> payload,
  ) {
    if (session.stage != PvpStage.blockDeclaration) {
      throw StateError('Blocks cannot be declared now');
    }
    if (actor != session.game.activePlayer.opponent) {
      throw StateError('Only the defending player may block');
    }
    final attacks = _attackDeclarations(payload, session.pendingAttackers);
    final game =
        _resolveCombat(session.game, session.game.activePlayer, attacks);
    if (game.winner != null) {
      return _Transition(
        session: session.copyWith(
          game: game,
          stage: PvpStage.finished,
          pendingAttackers: const [],
        ),
        event: const PvpEvent('match_finished'),
      );
    }
    final nextGame = Game.nextPhase(game);
    return _Transition(
      session: session.copyWith(
        game: nextGame,
        stage: PvpStage.main,
        priority: nextGame.activePlayer,
        pendingAttackers: const [],
      ),
      event: const PvpEvent('combat_resolved'),
    );
  }

  static _Transition _passPriority(PvpSession session, PlayerId actor) {
    if (session.stage != PvpStage.chainPriority) {
      throw StateError('There is no Chain priority window');
    }
    if (actor != session.priority) {
      throw StateError('Only the priority player may pass');
    }
    if (session.passCount == 0) {
      return _Transition(
        session: session.copyWith(
          priority: actor.opponent,
          passCount: 1,
        ),
        event: PvpEvent('priority_passed', payload: {'player': actor.name}),
      );
    }

    final game = Chain.resolveTop(session.game);
    if (game.winner != null) {
      return _Transition(
        session: session.copyWith(game: game, stage: PvpStage.finished),
        event: const PvpEvent('match_finished'),
      );
    }
    final chainOpen = game.chain.isNotEmpty;
    return _Transition(
      session: session.copyWith(
        game: game,
        stage: chainOpen ? PvpStage.chainPriority : session.resumeStage,
        priority: game.activePlayer,
        passCount: 0,
      ),
      event: const PvpEvent('chain_resolved'),
    );
  }

  static _Transition _concede(PvpSession session, PlayerId actor) =>
      _Transition(
        session: session.copyWith(
          game: session.game.copyWith(winner: actor.opponent),
          stage: PvpStage.finished,
        ),
        event: PvpEvent('match_finished', payload: {
          'winner': actor.opponent.name,
          'reason': 'concede',
        }),
      );

  /// Phases where a player actually has something to decide.
  static bool _isActionablePhase(Phase phase) =>
      phase == Phase.main1 ||
      phase == Phase.combat ||
      phase == Phase.main2;

  static void _requireMainActor(PvpSession session, PlayerId actor) {
    if (session.stage != PvpStage.main) {
      throw StateError('The match is not in a main action stage');
    }
    _requireActivePlayer(session, actor);
    if (session.game.chain.isNotEmpty) {
      throw StateError('The Chain must be empty');
    }
    if (session.game.phase != Phase.main1 &&
        session.game.phase != Phase.main2) {
      throw StateError('Main action is not legal in this phase');
    }
  }

  static void _requireActivePlayer(PvpSession session, PlayerId actor) {
    if (session.game.activePlayer != actor) {
      throw StateError('It is not your turn');
    }
  }

  static List<AttackDeclaration> _attackDeclarations(
    Map<String, dynamic> payload,
    List<int> expectedAttackers,
  ) {
    final raw = payload['blocks'];
    if (raw is! List) throw const FormatException('blocks must be an array');
    final seen = <int>{};
    final attacks = <AttackDeclaration>[];
    for (final item in raw) {
      if (item is! Map) throw const FormatException('block must be an object');
      final map = Map<String, dynamic>.from(item);
      final attackerId = _payloadInt(map, 'attackerId');
      if (!seen.add(attackerId)) {
        throw const FormatException('attacker has duplicate block declaration');
      }
      final blockerIds = _payloadIntList(map, 'blockerIds');
      final uniqueBlockers = blockerIds.toSet();
      if (uniqueBlockers.length != blockerIds.length) {
        throw const FormatException('blocker is assigned more than once');
      }
      attacks.add(AttackDeclaration(
        attackerId: attackerId,
        blockerIds: blockerIds,
      ));
    }
    if (seen.length != expectedAttackers.length ||
        !seen.containsAll(expectedAttackers)) {
      throw const FormatException('Every attacker needs one block declaration');
    }
    return [
      for (final id in expectedAttackers)
        attacks.firstWhere((attack) => attack.attackerId == id),
    ];
  }

  static GameState _resolveCombat(
    GameState game,
    PlayerId attacker,
    List<AttackDeclaration> attacks,
  ) {
    final before = <int, CardInstance>{
      for (final card in game.p1.arena) card.instanceId: card,
      for (final card in game.p2.arena) card.instanceId: card,
    };
    var next = Combat.resolveDamage(game, attacker, attacks);
    final after = {
      for (final card in next.p1.arena) card.instanceId,
      for (final card in next.p2.arena) card.instanceId,
    };
    final dead = [
      for (final entry in before.entries)
        if (!after.contains(entry.key)) entry.value,
    ];
    if (dead.isNotEmpty) {
      next = EffectInterpreter.fireDeathTriggers(next, dead);
    }
    return next;
  }

  static List<EffectTarget> _targets(Map<String, dynamic> payload) {
    final raw = payload['targets'] ?? const [];
    if (raw is! List) throw const FormatException('targets must be an array');
    return [
      for (final item in raw)
        _target(item is Map ? Map<String, dynamic>.from(item) : null),
    ];
  }

  static EffectTarget _target(Map<String, dynamic>? payload) {
    if (payload == null)
      throw const FormatException('target must be an object');
    switch (payload['kind']) {
      case 'unit':
        return EffectTarget.unit(_payloadInt(payload, 'instanceId'));
      case 'player':
        final name = payload['playerId'];
        if (name is! String)
          throw const FormatException('playerId is required');
        return EffectTarget.player(PlayerId.values.byName(name));
      default:
        throw const FormatException('Unknown target kind');
    }
  }

  static int _payloadInt(Map<String, dynamic> payload, String field) {
    final value = payload[field];
    if (value is! int) throw FormatException('$field must be an integer');
    return value;
  }

  static List<int> _payloadIntList(
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = payload[field];
    if (value is! List) throw FormatException('$field must be an array');
    return [
      for (final item in value)
        if (item is int)
          item
        else
          throw FormatException('$field must contain integers'),
    ];
  }

  static void _requireDeck(List<CardDef> deck, String player) {
    if (deck.length != 40) {
      throw ArgumentError('$player deck must contain exactly 40 cards');
    }
  }

  static PvpCommandResult _reject(
    PvpSession session,
    String code,
    String message,
  ) =>
      PvpCommandResult(
        session: session,
        error: PvpRuleError(code, message),
        events: [
          PvpEvent('command_rejected', payload: {'code': code})
        ],
      );

  static String _stateErrorMessage(StateError error) =>
      error.toString().replaceFirst('Bad state: ', '');

  static String _stateErrorCode(String message) => switch (message) {
        'It is not your turn' => 'not_your_turn',
        'Only the priority player may respond' => 'not_priority_player',
        'Only the priority player may pass' => 'not_priority_player',
        'Only the defending player may block' => 'not_defender',
        'The match is not in a main action stage' => 'illegal_stage',
        'The Chain must be empty' => 'chain_open',
        _ => 'illegal_action',
      };
}

class _Transition {
  final PvpSession? session;

  /// What to publish, or null when there is nothing worth telling anyone.
  ///
  /// Every published event lands in pvp_events, which Realtime pushes to both
  /// clients, each of which then refetches the whole projection. That is the
  /// right cost for a real move and pure waste for presence traffic.
  final PvpEvent? event;
  final bool incrementsRevision;

  const _Transition({
    required this.session,
    this.event,
    this.incrementsRevision = true,
  });
}
