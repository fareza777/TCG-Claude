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
  final String kind; // 'attack' | 'damagePlayer' | 'draw' | 'play' | 'proc' ...
  final int? instanceId;
  final int? amount;
  final PlayerId? player;
  final String? label; // e.g. keyword name for a 'proc' flash, turn banner text

  const DuelEvent(this.kind,
      {this.instanceId, this.amount, this.player, this.label});
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

  /// While the enemy resolves a spell, the UI shows a "casting" banner and a
  /// reticle on [enemyCastTargetId]. Both are null when nothing is being cast.
  /// [enemyCastAtPlayer] is true when the spell aims at the human's face.
  String? enemyCastName;
  int? enemyCastTargetId;
  bool enemyCastAtPlayer = false;

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
    if (firstPlayer == human && !isGameOver) {
      _emit(DuelEvent('turnStart', player: human));
      notifyListeners();
    }
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

  /// Attune mode: the next hand card tapped is turned face-down into a
  /// generic Wellspring (anti-mana-screw). Toggled from the action bar.
  bool attuneMode = false;

  bool get canAttune =>
      ui == DuelUiState.playerMain &&
      !busy &&
      !me.playedWellspringThisTurn &&
      me.hand.isNotEmpty;

  void toggleAttuneMode() {
    if (!canAttune && !attuneMode) return;
    attuneMode = !attuneMode;
    targetingId = null;
    lastError = null;
    notifyListeners();
  }

  void playHandCard(int instanceId) {
    if (isGameOver) return;

    // Attune consumes the tapped card into a Wellspring instead of playing it.
    if (attuneMode) {
      attuneMode = false;
      try {
        state = Game.attune(state, human, instanceId);
        _log('You Attune a card into a generic Wellspring.');
        _emit(const DuelEvent('play'));
      } on StateError catch (e) {
        lastError = e.message;
      }
      notifyListeners();
      return;
    }

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
    try {
      if (card.def.type == CardType.wellspring) {
        state = Game.playWellspring(state, human, card.instanceId);
        _log('You placed ${card.def.name}.');
        _emit(DuelEvent('play', instanceId: card.instanceId));
      } else if (card.def.type == CardType.unit) {
        final foeHandBefore = foe.hand.length;
        _ensureAether(card.def);
        state = Game.playUnit(state, human, card.instanceId, chosen: targets);
        _log(targetLabel == null
            ? 'You summoned ${card.def.name}.'
            : 'You summoned ${card.def.name}, targeting $targetLabel.');
        _emit(DuelEvent('play', instanceId: card.instanceId));
        for (var i = 0; i < foeHandBefore - foe.hand.length; i++) {
          _emit(DuelEvent('discard', player: enemy));
        }
        _checkGameOver();
        _pruneDeadAttackers();
      } else {
        // Spell (Rite/Ritual): cast onto the chain, then give the enemy an
        // instant-speed response before the chain resolves.
        _ensureAether(card.def);
        state = Chain.cast(state, human, card.instanceId, targets: targets);
        _log(targetLabel == null
            ? 'You cast ${card.def.name}.'
            : 'You cast ${card.def.name} at $targetLabel.');
        _emit(DuelEvent('play', instanceId: card.instanceId));
        notifyListeners();
        unawaited(_resolvePlayerSpellChain());
        return;
      }
    } on StateError catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  /// Resolve a spell the human just put on the chain: the enemy may respond at
  /// instant speed (counter or snipe), then the whole chain resolves with the
  /// same readable feedback used on the enemy's turn.
  Future<void> _resolvePlayerSpellChain() async {
    Future<void> beat([int ms = 360]) async {
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: ms));
    }

    // Enemy instant-speed response (one level deep).
    final resp = isGameOver ? null : enemyAi.chooseResponse(state, enemy);
    if (resp != null) {
      final rc = foe.hand.where((c) => c.instanceId == resp.cardId).firstOrNull;
      if (rc != null) {
        enemyCastName = rc.def.name;
        enemyCastTargetId = resp.unitTargetId;
        enemyCastAtPlayer = resp.targets.any((t) => t.playerId == human);
        _log('Enemy responds with ${rc.def.name}.');
        _emit(const DuelEvent('play'));
        await beat(1050);
        try {
          state = Chain.cast(state, enemy, resp.cardId, targets: resp.targets);
        } on StateError {
          // ignore — could not afford after all
        }
        enemyCastName = null;
        enemyCastTargetId = null;
        enemyCastAtPlayer = false;
      }
    }

    // Snapshot, resolve the chain, then surface every effect.
    final myUnitsBefore = {for (final c in me.arena) c.instanceId};
    final foeUnitsBefore = {for (final c in foe.arena) c.instanceId};
    final dmgBefore = <int, int>{
      for (final c in [...me.arena, ...foe.arena]) c.instanceId: c.damage,
    };
    final myHpBefore = me.health;
    final foeHpBefore = foe.health;
    final foeHandBefore = foe.hand.length;

    state = Chain.resolveAll(state);

    final myUnitsAfter = {for (final c in me.arena) c.instanceId};
    final foeUnitsAfter = {for (final c in foe.arena) c.instanceId};
    final died = myUnitsBefore.difference(myUnitsAfter).length +
        foeUnitsBefore.difference(foeUnitsAfter).length;
    for (var i = 0; i < died; i++) {
      _emit(const DuelEvent('death'));
    }
    for (final c in [...me.arena, ...foe.arena]) {
      final d = c.damage - (dmgBefore[c.instanceId] ?? c.damage);
      if (d > 0) {
        _emit(DuelEvent('unitDamaged',
            instanceId: c.instanceId, amount: d, player: c.owner));
      }
    }
    final foeHpLost = foeHpBefore - foe.health;
    if (foeHpLost > 0) {
      _emit(DuelEvent('damagePlayer', amount: foeHpLost, player: enemy));
    }
    final myHpLost = myHpBefore - me.health;
    if (myHpLost > 0) {
      _emit(DuelEvent('damagePlayer', amount: myHpLost, player: human));
    }
    for (var i = 0; i < foeHandBefore - foe.hand.length; i++) {
      _emit(DuelEvent('discard', player: enemy));
    }

    // Hold on the result so the resolution reads before the board settles.
    await beat(1000);
    _checkGameOver();
    _pruneDeadAttackers();
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

    // Collect the "flashy" keywords among combatants for proc callouts.
    const flashy = {
      Keyword.swiftstrike,
      Keyword.venom,
      Keyword.leech,
      Keyword.rampage,
    };
    final procs = <Keyword>{};
    for (final b in blocks) {
      final atk = before[b.attackerId];
      if (atk != null) procs.addAll(atk.keywords.where(flashy.contains));
      if (b.blockerIds.isNotEmpty) {
        for (final bid in b.blockerIds) {
          final bl = before[bid];
          if (bl != null) procs.addAll(bl.keywords.where(flashy.contains));
        }
      }
    }

    state = Combat.resolveDamage(state, attacker, blocks);

    for (final kw in procs) {
      _emit(DuelEvent('proc', label: kw.name.toUpperCase()));
    }
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

  /// Runs one enemy main phase as a paced sequence: resources → deploy units
  /// one by one (pop-in) → cast spells one by one, each spell announced with a
  /// banner + reticle on its target BEFORE it resolves. This is what makes
  /// enemy removal readable ("card out, then target") instead of a unit
  /// silently vanishing.
  Future<void> _enemyMainPhaseStaged(
      Future<void> Function([int]) beat) async {
    // 1. Resources (no visible play).
    state = enemyAi.playResources(state, enemy);

    // 2. Deploy units one at a time — the arena pop-in keys off the new id.
    while (true) {
      final r = enemyAi.deployNextUnit(state, enemy);
      if (r == null) break;
      final unit =
          r.state.player(enemy).arena.firstWhere((c) => c.instanceId == r.deployedId);
      state = r.state;
      _log('Enemy deploys ${unit.def.name}.');
      await beat(760);
      if (_gameOverNow()) return;
    }

    // 3. Cast spells one at a time, with a visible aim step.
    while (true) {
      final sp = enemyAi.nextSpell(state, enemy);
      if (sp == null) break;
      final card =
          foe.hand.firstWhere((c) => c.instanceId == sp.cardId);

      // Does this spell aim at the human player's face (vs a unit)?
      final atPlayer = sp.targets.any((t) => t.playerId == human);

      // Step A — announce: the spell card is played to the board.
      enemyCastName = card.def.name;
      enemyCastTargetId = sp.unitTargetId;
      enemyCastAtPlayer = atPlayer;
      _emit(DuelEvent('play'));
      _log('Enemy casts ${card.def.name}.');
      await beat(950);

      // Step B — the aim lands (reticle on your unit, or a pulse on your
      // face) and is held long enough to read before anything resolves.
      if (sp.unitTargetId != null) {
        _log('${card.def.name} targets your unit.');
      } else if (atPlayer) {
        _log('${card.def.name} targets you.');
      }
      await beat(1150);

      // Snapshot to detect exactly what the effect did.
      final myUnitsBefore = {for (final c in me.arena) c.instanceId};
      final foeUnitsBefore = {for (final c in foe.arena) c.instanceId};
      final dmgBefore = <int, int>{
        for (final c in [...me.arena, ...foe.arena]) c.instanceId: c.damage,
      };
      final myHandBefore = me.hand.length;
      final foeHandBefore = foe.hand.length;
      final myHpBefore = me.health;
      final foeHpBefore = foe.health;
      try {
        state = Chain.resolveAll(
            Chain.cast(state, enemy, sp.cardId, targets: sp.targets));
      } on StateError {
        enemyCastName = null;
        enemyCastTargetId = null;
        enemyCastAtPlayer = false;
        break;
      }

      // Step C — show the effect. Deaths, unit damage, face damage, discards
      // and draws each get their own readable callout so nothing is silent.
      final myUnitsAfter = {for (final c in me.arena) c.instanceId};
      final foeUnitsAfter = {for (final c in foe.arena) c.instanceId};
      final died = myUnitsBefore.difference(myUnitsAfter).length +
          foeUnitsBefore.difference(foeUnitsAfter).length;
      for (var i = 0; i < died; i++) {
        _emit(const DuelEvent('death'));
      }
      // Surviving units that took damage flash + float their loss, so a
      // non-lethal hit is never silent either.
      for (final c in [...me.arena, ...foe.arena]) {
        final d = c.damage - (dmgBefore[c.instanceId] ?? c.damage);
        if (d > 0) {
          _emit(DuelEvent('unitDamaged',
              instanceId: c.instanceId, amount: d, player: c.owner));
        }
      }
      // Face damage — this was the silent case: an "any target" spell hitting
      // the player now flashes and floats a damage number like combat does.
      final myHpLost = myHpBefore - me.health;
      if (myHpLost > 0) {
        _log('You take $myHpLost damage.');
        _emit(DuelEvent('damagePlayer', amount: myHpLost, player: human));
      }
      final foeHpLost = foeHpBefore - foe.health;
      if (foeHpLost > 0) {
        _emit(DuelEvent('damagePlayer', amount: foeHpLost, player: enemy));
      }
      for (var i = 0; i < myHandBefore - me.hand.length; i++) {
        _emit(DuelEvent('discard', player: human));
      }
      if (myHandBefore > me.hand.length) {
        _log('You discard ${myHandBefore - me.hand.length} card(s).');
      }
      final foeDrew = foe.hand.length - foeHandBefore;
      if (foeDrew > 0) _log('Enemy draws $foeDrew card(s).');

      // Hold on the result — banner + damage/death floats still visible — so
      // the player clearly sees what happened before the board settles.
      await beat(1250);
      enemyCastName = null;
      enemyCastTargetId = null;
      enemyCastAtPlayer = false;
      await beat(450);
      if (_gameOverNow()) return;
      if (state.winner != null) return;
    }
  }

  Future<void> _runEnemyTurnStaged() async {
    Future<void> beat([int ms = 420]) async {
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: ms));
    }

    if (isGameOver) return;
    _emit(DuelEvent('turnStart', player: enemy));
    await beat(650);

    // Normalize to the enemy's Main 1. Handles both the post-endTurn start
    // (enemy at refresh) and the enemy-on-the-play opening (already at main1,
    // draw skipped). This prevents phase-drift that used to dump the player
    // into Main 2 and let the enemy take two main phases.
    while (state.activePlayer == enemy && state.phase != Phase.main1) {
      state = Game.nextPhase(state);
      if (_gameOverNow()) return;
      await beat(300);
    }

    await _enemyMainPhaseStaged(beat); // Main 1
    if (_gameOverNow()) return;
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
      await beat(720);
      final blocks = await _awaitPlayerBlocks(attackerIds);
      final beforeHp = me.health;
      _resolveCombat(enemy, blocks);
      final dealt = beforeHp - me.health;
      if (dealt > 0) {
        _log('You take $dealt damage.');
        _emit(DuelEvent('damagePlayer', amount: dealt, player: human));
      }
      if (_gameOverNow()) return;
      await beat(1000);
    }

    state = Game.nextPhase(state); // -> main2
    await _enemyMainPhaseStaged(beat);
    if (_gameOverNow()) return;
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
    _emit(DuelEvent('turnStart', player: human));
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
