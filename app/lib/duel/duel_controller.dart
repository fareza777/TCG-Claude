import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'scenario.dart';

enum DuelUiState {
  playerMain,
  playerCombat,
  playerBlocking,
  playerResponse,
  enemyTurn,
  gameOver
}

class DuelEvent {
  final String kind; // 'attack' | 'damagePlayer' | 'draw' | 'play'
  final int? instanceId;
  final int? amount;
  final PlayerId? player;

  const DuelEvent(this.kind, {this.instanceId, this.amount, this.player});
}

/// What a pending spell/ability is allowed to aim at.
class TargetSpec {
  final bool units;
  final bool players;
  const TargetSpec({required this.units, required this.players});
}

/// Drives one PvE duel: human = p1, AI = p2.
class DuelController extends ChangeNotifier {
  GameState state;
  DuelUiState ui = DuelUiState.playerMain;
  final AiPlayer enemyAi;
  final AiPlayer helperAi = const AiPlayer(tier: AiTier.tactician);
  final Set<int> selectedAttackers = {};
  final List<DuelEvent> pendingEvents = [];
  final List<String> history = [];
  String? lastError;
  bool busy = false;

  /// Card in hand waiting for the player to pick a target.
  int? targetingId;

  /// While the enemy is attacking, the player assigns blockers.
  List<int> incomingAttackers = [];
  Map<int, List<int>> blockPlan = {}; // attackerId -> [blockerIds]
  int? blockingSelectedAttacker;
  Completer<List<AttackDeclaration>>? _blockCompleter;

  /// Instant-speed response window during the enemy's main phases.
  Completer<void>? _responseCompleter;

  /// Whether the human takes the first turn (coin flip in skirmish).
  final PlayerId firstPlayer;

  static const human = PlayerId.p1;
  static const enemy = PlayerId.p2;

  DuelController({
    required List<CardDef> playerDeck,
    required List<CardDef> enemyDeck,
    int? seed,
    BattleScenario? scenario,
    this.firstPlayer = PlayerId.p1,
    AiTier aiTier = AiTier.tactician,
  })  : enemyAi = AiPlayer(tier: aiTier),
        state = Game.create(
          deckP1: playerDeck,
          deckP2: enemyDeck,
          seed: seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
          firstPlayer: firstPlayer,
        ) {
    if (scenario != null && scenario.isModified) {
      state = scenario.apply(state, human: human, enemy: enemy);
    }
    _log(firstPlayer == human
        ? 'You won the flip and take the first turn.'
        : 'The enemy takes the first turn.');
  }

  /// Opening hand mulligan (Redraw), once per game.
  bool awaitingMulligan = true;
  bool mulliganUsed = false;

  void redrawHand() {
    if (!awaitingMulligan || mulliganUsed) return;
    state = Game.redraw(state, human);
    mulliganUsed = true;
    _log('You redraw your opening hand.');
    notifyListeners();
  }

  Future<void> confirmHand() async {
    if (!awaitingMulligan) return;
    awaitingMulligan = false;
    notifyListeners();
    await begin();
  }

  /// Called after the mulligan. If the enemy is on the play, run its opening
  /// turn immediately.
  Future<void> begin() async {
    if (firstPlayer == enemy && !busy && !isGameOver) {
      busy = true;
      ui = DuelUiState.enemyTurn;
      notifyListeners();
      await _runEnemyTurnStaged();
      busy = false;
      notifyListeners();
    }
  }

  PlayerState get me => state.player(human);
  PlayerState get foe => state.player(enemy);
  bool get isGameOver => state.winner != null;
  bool get playerWon => state.winner == human;
  bool get isTargeting => targetingId != null;

  CardDef? get targetingDef {
    final id = targetingId;
    if (id == null) return null;
    return me.hand
        .where((c) => c.instanceId == id)
        .firstOrNull
        ?.def;
  }

  void _emit(DuelEvent e) => pendingEvents.add(e);

  void _log(String s) {
    history.add('Turn ${state.turnNumber} — $s');
    if (history.length > 200) history.removeAt(0);
  }

  List<DuelEvent> takeEvents() {
    final out = List<DuelEvent>.from(pendingEvents);
    pendingEvents.clear();
    return out;
  }

  int get potentialAether =>
      me.totalAether +
      me.arena
          .where((c) => c.def.type == CardType.wellspring && !c.exerted)
          .length;

  bool canAfford(CardDef def) => potentialAether >= def.totalCost;

  // ── targeting ─────────────────────────────────────────────────────────

  /// Number of CHOOSE selectors in a card's effects.
  static int chooseCount(CardDef def) {
    var n = 0;
    for (final block in def.effects) {
      for (final raw in (block['effects'] as List? ?? const [])) {
        final sel = ((raw as Map)['target'] as Map?)?['select'];
        if (sel == 'CHOOSE') n++;
      }
    }
    return n;
  }

  /// Determine what the pending card may target.
  TargetSpec targetSpec(CardDef def) {
    var players = false;
    for (final block in def.effects) {
      for (final raw in (block['effects'] as List? ?? const [])) {
        final effect = raw as Map;
        final sel = (effect['target'] as Map?)?['select'];
        if (sel != 'CHOOSE') continue;
        if (effect['op'] == 'DEAL_DAMAGE' &&
            def.text.toLowerCase().contains('any target')) {
          players = true;
        }
      }
    }
    return TargetSpec(units: true, players: players);
  }

  /// Whether any legal target exists right now for the pending card.
  bool hasLegalTarget(CardDef def) {
    final spec = targetSpec(def);
    if (spec.players) return true;
    return [...me.arena, ...foe.arena]
        .any((c) => c.def.type == CardType.unit);
  }

  void playHandCard(int instanceId) {
    if (isGameOver) return;
    // Instant-speed: during the enemy's attack, only Rites may be cast in
    // response. Otherwise normal main-phase rules (and never while busy).
    final responding = ui == DuelUiState.playerBlocking ||
        ui == DuelUiState.playerResponse;
    if (!responding && (ui == DuelUiState.enemyTurn || busy)) return;
    final card = me.hand.where((c) => c.instanceId == instanceId).firstOrNull;
    if (card == null) return;
    if (responding && card.def.type != CardType.rite) return;
    lastError = null;

    if (chooseCount(card.def) > 0) {
      if (!hasLegalTarget(card.def)) {
        lastError = 'No legal targets for ${card.def.name}.';
        notifyListeners();
        return;
      }
      targetingId = instanceId; // enter aiming mode
      notifyListeners();
      return;
    }
    _resolvePlay(card, const []);
  }

  /// Player tapped a unit while aiming.
  void selectUnitTarget(int unitInstanceId) {
    final id = targetingId;
    if (id == null) return;
    final card = me.hand.where((c) => c.instanceId == id).firstOrNull;
    if (card == null) {
      targetingId = null;
      notifyListeners();
      return;
    }
    targetingId = null;
    _resolvePlay(card, [EffectTarget.unit(unitInstanceId)],
        targetLabel: _unitName(unitInstanceId));
  }

  /// Player tapped a player face while aiming.
  void selectPlayerTarget(PlayerId pid) {
    final id = targetingId;
    if (id == null) return;
    final card = me.hand.where((c) => c.instanceId == id).firstOrNull;
    if (card == null || !targetSpec(card.def).players) return;
    targetingId = null;
    _resolvePlay(card, [EffectTarget.player(pid)],
        targetLabel: pid == human ? 'you' : 'the enemy');
  }

  void cancelTargeting() {
    targetingId = null;
    notifyListeners();
  }

  String _unitName(int instanceId) {
    for (final p in [me, foe]) {
      final c = p.arena.where((u) => u.instanceId == instanceId).firstOrNull;
      if (c != null) return c.def.name;
    }
    return 'a unit';
  }

  void _resolvePlay(CardInstance card, List<EffectTarget> targets,
      {String? targetLabel}) {
    final foeHandBefore = foe.hand.length;
    try {
      if (card.def.type == CardType.wellspring) {
        state = Game.playWellspring(state, human, card.instanceId);
        _log('You placed ${card.def.name}.');
      } else {
        _ensureAether(card.def);
        if (card.def.type == CardType.unit) {
          state =
              Game.playUnit(state, human, card.instanceId, chosen: targets);
          _log(targetLabel == null
              ? 'You summoned ${card.def.name}.'
              : 'You summoned ${card.def.name}, targeting $targetLabel.');
        } else {
          state = Chain.cast(state, human, card.instanceId, targets: targets);
          state = Chain.resolveAll(state);
          _log(targetLabel == null
              ? 'You cast ${card.def.name}.'
              : 'You cast ${card.def.name} at $targetLabel.');
        }
      }
      _emit(DuelEvent('play', instanceId: card.instanceId));
      final discarded = foeHandBefore - foe.hand.length;
      for (var i = 0; i < discarded; i++) {
        _emit(DuelEvent('discard', player: enemy));
      }
      _checkGameOver();
      _pruneDeadAttackers();
    } on StateError catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  /// After an instant-speed response kills attackers, drop them from the
  /// pending block assignment. If none remain, the block step auto-resolves.
  void _pruneDeadAttackers() {
    if (ui != DuelUiState.playerBlocking) return;
    final alive = foe.arena.map((c) => c.instanceId).toSet();
    incomingAttackers =
        incomingAttackers.where(alive.contains).toList();
    blockPlan.removeWhere((atk, _) => !alive.contains(atk));
    if (blockingSelectedAttacker != null &&
        !alive.contains(blockingSelectedAttacker)) {
      blockingSelectedAttacker =
          incomingAttackers.isNotEmpty ? incomingAttackers.first : null;
    }
    if (incomingAttackers.isEmpty && _blockCompleter != null) {
      final completer = _blockCompleter!;
      _blockCompleter = null;
      completer.complete(const []);
    }
  }

  void _ensureAether(CardDef def) {
    while (true) {
      try {
        Game.payCost(def, me.aetherPool);
        return;
      } on StateError {
        final ws = me.arena
            .where((c) => c.def.type == CardType.wellspring && !c.exerted)
            .firstOrNull;
        if (ws == null) rethrow;
        state = Game.exertForAether(state, human, ws.instanceId);
      }
    }
  }

  // ── combat ────────────────────────────────────────────────────────────

  void toggleAttacker(int instanceId) {
    if (ui != DuelUiState.playerCombat) return;
    final unit = me.arena.where((c) => c.instanceId == instanceId).firstOrNull;
    if (unit == null || !unit.canAttack) return;
    if (unit.def.keywords.contains(Keyword.bulwark)) return;
    if (!selectedAttackers.remove(instanceId)) {
      selectedAttackers.add(instanceId);
    }
    notifyListeners();
  }

  /// Units that are legally able to attack this combat.
  List<CardInstance> get eligibleAttackers => me.arena
      .where((c) =>
          c.canAttack && !c.def.keywords.contains(Keyword.bulwark))
      .toList();

  /// Select every eligible attacker (or clear if all are already selected).
  void toggleAttackAll() {
    if (ui != DuelUiState.playerCombat) return;
    final eligible = eligibleAttackers.map((c) => c.instanceId).toSet();
    if (selectedAttackers.containsAll(eligible) && eligible.isNotEmpty) {
      selectedAttackers.clear();
    } else {
      selectedAttackers
        ..clear()
        ..addAll(eligible);
    }
    notifyListeners();
  }

  void enterCombat() {
    if (ui != DuelUiState.playerMain || isGameOver || isTargeting) return;
    state = Game.nextPhase(state);
    ui = DuelUiState.playerCombat;
    selectedAttackers.clear();
    notifyListeners();
  }

  Future<void> confirmAttack() async {
    if (ui != DuelUiState.playerCombat || busy) return;
    if (selectedAttackers.isNotEmpty) {
      busy = true;
      final ids = selectedAttackers.toList();
      state = Combat.declareAttackers(state, human, ids);
      _log('You attack with ${ids.map(_unitName).join(', ')}.');
      for (final id in ids) {
        _emit(DuelEvent('attack', instanceId: id));
      }
      selectedAttackers.clear();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 480)); // lunge
      final blocks = enemyAi.chooseBlocks(state, enemy, ids);
      final before = foe.health;
      _resolveCombat(human, blocks);
      final dealt = before - foe.health;
      if (dealt > 0) {
        _log('Enemy takes $dealt damage.');
        _emit(DuelEvent('damagePlayer', amount: dealt, player: enemy));
      }
      busy = false;
    }
    selectedAttackers.clear();
    _checkGameOver();
    if (!isGameOver) {
      state = Game.nextPhase(state);
      ui = DuelUiState.playerMain;
    }
    notifyListeners();
  }

  /// Resolve combat damage and emit a `death` event for every Unit that
  /// leaves the Arena, so the UI can animate the loss.
  void _resolveCombat(PlayerId attacker, List<AttackDeclaration> blocks) {
    final before = <int, CardInstance>{
      for (final c in me.arena) c.instanceId: c,
      for (final c in foe.arena) c.instanceId: c,
    };
    state = Combat.resolveDamage(state, attacker, blocks);
    final after = <int>{
      for (final c in me.arena) c.instanceId,
      for (final c in foe.arena) c.instanceId,
    };
    final dead = <CardInstance>[];
    for (final entry in before.entries) {
      if (!after.contains(entry.key)) {
        _emit(DuelEvent('death', instanceId: entry.key));
        _log('${entry.value.def.name} is destroyed.');
        dead.add(entry.value);
      }
    }
    // Fire ON_DEATH triggers for units that died in combat.
    if (dead.isNotEmpty) {
      state = EffectInterpreter.fireDeathTriggers(state, dead);
    }
  }

  // ── player blocking (defending against enemy attack) ──────────────────

  Future<List<AttackDeclaration>> _awaitPlayerBlocks(
      List<int> attackerIds) async {
    final hasBlocker = me.arena
        .any((c) => c.def.type == CardType.unit && !c.exerted);
    if (!hasBlocker) {
      return [for (final id in attackerIds) AttackDeclaration(attackerId: id)];
    }
    incomingAttackers = List.of(attackerIds);
    blockPlan = {};
    blockingSelectedAttacker = attackerIds.isNotEmpty ? attackerIds.first : null;
    ui = DuelUiState.playerBlocking;
    _blockCompleter = Completer<List<AttackDeclaration>>();
    notifyListeners();
    final blocks = await _blockCompleter!.future;
    incomingAttackers = [];
    blockPlan = {};
    blockingSelectedAttacker = null;
    ui = DuelUiState.enemyTurn;
    notifyListeners();
    return blocks;
  }

  void selectAttackerToBlock(int attackerId) {
    if (ui != DuelUiState.playerBlocking) return;
    blockingSelectedAttacker =
        blockingSelectedAttacker == attackerId ? null : attackerId;
    notifyListeners();
  }

  /// Toggle one of your untapped Units as a blocker of the selected attacker.
  void assignBlocker(int blockerId) {
    if (ui != DuelUiState.playerBlocking) return;
    final atk = blockingSelectedAttacker;
    if (atk == null) return;
    final blocker =
        me.arena.where((c) => c.instanceId == blockerId).firstOrNull;
    if (blocker == null || blocker.exerted ||
        blocker.def.type != CardType.unit) {
      return;
    }
    // A blocker may only block one attacker: clear it elsewhere first.
    for (final list in blockPlan.values) {
      list.remove(blockerId);
    }
    final list = blockPlan.putIfAbsent(atk, () => []);
    if (list.contains(blockerId)) {
      list.remove(blockerId);
    } else {
      list.add(blockerId);
    }
    blockPlan.removeWhere((_, v) => v.isEmpty);
    notifyListeners();
  }

  int? blockerAssignedTo(int blockerId) {
    for (final entry in blockPlan.entries) {
      if (entry.value.contains(blockerId)) return entry.key;
    }
    return null;
  }

  // ── instant-speed response window (enemy main phases) ─────────────────
  bool _playerHasCastableRite() => me.hand.any((c) =>
      c.def.type == CardType.rite && potentialAether >= c.def.totalCost);

  Future<void> _awaitResponse() async {
    if (isGameOver || !_playerHasCastableRite()) return;
    ui = DuelUiState.playerResponse;
    _responseCompleter = Completer<void>();
    notifyListeners();
    await _responseCompleter!.future;
    if (ui == DuelUiState.playerResponse) ui = DuelUiState.enemyTurn;
    notifyListeners();
  }

  void passResponse() {
    if (ui != DuelUiState.playerResponse) return;
    final completer = _responseCompleter;
    if (completer == null || completer.isCompleted) return;
    _responseCompleter = null;
    completer.complete();
  }

  /// Clear all assigned blockers (unstick an invalid assignment).
  void clearBlocks() {
    if (ui != DuelUiState.playerBlocking) return;
    blockPlan = {};
    lastError = null;
    notifyListeners();
  }

  void confirmBlocks() {
    if (ui != DuelUiState.playerBlocking || _blockCompleter == null) return;
    final decls = [
      for (final atk in incomingAttackers)
        AttackDeclaration(attackerId: atk, blockerIds: blockPlan[atk] ?? const []),
    ];
    try {
      Combat.validateBlocks(state, human, decls);
    } on StateError catch (e) {
      // Invalid (e.g. Dread needs 2 blockers). Surface it; the player can
      // adjust or Clear — never stuck.
      lastError = e.message;
      notifyListeners();
      return;
    }
    lastError = null;
    final completer = _blockCompleter!;
    _blockCompleter = null;
    completer.complete(decls);
  }

  /// Concede the duel — the player loses immediately.
  void surrender() {
    if (isGameOver) return;
    state = state.copyWith(winner: enemy);
    _log('You concede the duel.');
    _checkGameOver();
    notifyListeners();
  }

  Future<void> endTurn() async {
    if (isGameOver || busy) return;
    busy = true;
    targetingId = null;
    while (state.activePlayer == human && state.phase != Phase.refresh) {
      state = Game.nextPhase(state);
      if (state.activePlayer != human) break;
    }
    ui = DuelUiState.enemyTurn;
    _log('You end your turn.');
    notifyListeners();
    await _runEnemyTurnStaged();
    busy = false;
    notifyListeners();
  }

  Future<void> _runEnemyTurnStaged() async {
    Future<void> beat([int ms = 420]) async {
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: ms));
    }

    Set<int> arenaIds() => {for (final c in foe.arena) c.instanceId};

    void logNewPlays(Set<int> before) {
      for (final c in foe.arena) {
        if (!before.contains(c.instanceId) &&
            c.def.type != CardType.wellspring) {
          _log('Enemy deployed ${c.def.name}.');
        }
      }
    }

    if (isGameOver) return;
    await beat(350);

    // Normalize to the enemy's Main 1. Handles both the post-endTurn start
    // (enemy at refresh) and the enemy-on-the-play opening (already at main1,
    // draw skipped). This prevents phase-drift that used to dump the player
    // into Main 2 and let the enemy take two main phases.
    while (state.activePlayer == enemy && state.phase != Phase.main1) {
      state = Game.nextPhase(state);
      if (_gameOverNow()) return;
      await beat(300);
    }

    var before = arenaIds();
    var myHandBefore = me.hand.length;
    state = enemyAi.playMainPhase(state, enemy); // Main 1
    logNewPlays(before);
    for (var i = 0; i < myHandBefore - me.hand.length; i++) {
      _emit(DuelEvent('discard', player: human));
    }
    if (_gameOverNow()) return;
    await beat(520);
    await _awaitResponse(); // instant-speed after enemy Main 1
    if (_gameOverNow()) return;

    state = Game.nextPhase(state); // -> combat
    await beat(320);
    final attackerIds = enemyAi.chooseAttackers(state, enemy);
    if (attackerIds.isNotEmpty) {
      state = Combat.declareAttackers(state, enemy, attackerIds);
      _log('Enemy attacks with '
          '${attackerIds.map((id) => foe.arena.firstWhere((c) => c.instanceId == id).def.name).join(', ')}.');
      for (final id in attackerIds) {
        _emit(DuelEvent('attack', instanceId: id));
      }
      await beat(560);
      final blocks = await _awaitPlayerBlocks(attackerIds);
      final beforeHp = me.health;
      _resolveCombat(enemy, blocks);
      final dealt = beforeHp - me.health;
      if (dealt > 0) {
        _log('You take $dealt damage.');
        _emit(DuelEvent('damagePlayer', amount: dealt, player: human));
      }
      if (_gameOverNow()) return;
      await beat(420);
    }

    state = Game.nextPhase(state); // -> main2
    before = arenaIds();
    myHandBefore = me.hand.length;
    state = enemyAi.playMainPhase(state, enemy);
    logNewPlays(before);
    for (var i = 0; i < myHandBefore - me.hand.length; i++) {
      _emit(DuelEvent('discard', player: human));
    }
    if (_gameOverNow()) return;
    await beat(420);
    await _awaitResponse(); // instant-speed after enemy Main 2
    if (_gameOverNow()) return;

    state = Game.nextPhase(state); // -> end
    await beat(300);
    state = Game.nextPhase(state); // enemy end -> player refresh
    await beat(300);
    // Normalize the player to their Main 1 (refresh -> draw -> main1).
    while (state.activePlayer == human && state.phase != Phase.main1) {
      state = Game.nextPhase(state);
    }
    _log('Your turn.');
    _emit(const DuelEvent('draw', player: human));
    if (_gameOverNow()) return;
    ui = DuelUiState.playerMain;
  }

  bool _gameOverNow() {
    _checkGameOver();
    if (isGameOver) {
      notifyListeners();
      return true;
    }
    return false;
  }

  void _checkGameOver() {
    if (state.winner != null && ui != DuelUiState.gameOver) {
      ui = DuelUiState.gameOver;
      _log(playerWon ? 'VICTORY.' : 'DEFEAT.');
      // Release any awaited window so the staged enemy turn unwinds cleanly
      // instead of hanging (e.g. an instant-speed kill during blocking).
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.complete();
        _responseCompleter = null;
      }
      if (_blockCompleter != null && !_blockCompleter!.isCompleted) {
        _blockCompleter!.complete(const []);
        _blockCompleter = null;
      }
    }
  }
}
