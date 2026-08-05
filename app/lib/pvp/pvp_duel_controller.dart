import 'dart:async';

import 'package:shardfall_engine/shardfall_engine.dart';

import '../duel/duel_controller.dart';
import 'pvp_controller.dart';
import 'pvp_game_state.dart';
import 'pvp_models.dart';

/// Drives the shared battle screen from an online match.
///
/// The PvE duel screen is a large, finished piece of UI. Rather than rebuild a
/// second, poorer version of it for PvP — which is what the old PvP match
/// screen was — this subclass presents the online match through exactly the
/// same surface the screen already reads, so the screen itself needs no change
/// at all and the PvE path is untouched.
///
/// The inherited rules engine is never run here. Every player action is sent to
/// the authoritative server, and the board is replaced wholesale by whatever
/// the next projection says. That means an illegal move simply does not happen,
/// rather than happening locally and then being corrected.
class PvpDuelController extends DuelController {
  PvpDuelController({
    required this.pvp,
    required this.library,
    required List<CardDef> deck,
  }) : super(
          // Only used to satisfy the base constructor. The first projection
          // replaces this board before anything is drawn.
          playerDeck: _openingDeck(deck),
          enemyDeck: _openingDeck(deck),
          seed: 1,
        ) {
    pvp.addListener(_onProjection);
    _onProjection();
  }

  final PvpController pvp;
  final CardLibrary library;

  /// The base constructor deals an opening hand, so it needs a deck big enough
  /// to draw from. Callers should not have to care: a short or empty list would
  /// otherwise crash the screen before the server's board ever arrives.
  static List<CardDef> _openingDeck(List<CardDef> deck) {
    if (deck.length >= _minimumDeck) return deck;
    return [
      ...deck,
      for (var i = deck.length; i < _minimumDeck; i++) PvpGameState.hiddenCard,
    ];
  }

  static const _minimumDeck = 12;

  /// Which seat the server gave this player. [PvpGameState] draws the viewer as
  /// p1 regardless, so anything sent back has to be translated to this.
  PlayerId _seat = PlayerId.p1;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    pvp.removeListener(_onProjection);
    super.dispose();
  }

  // ── server state in ───────────────────────────────────────────────────

  void _onProjection() {
    if (_disposed) return;
    final projection = pvp.projection;
    if (projection == null) return;

    _seat = projection.viewer;
    state = PvpGameState.fromProjection(projection, library);
    ui = _uiFor(projection);
    awaitingMulligan = projection.stage == PvpStage.waitingForReady ||
        projection.stage == PvpStage.mulligan;
    mulliganUsed = projection.stage == PvpStage.mulligan && !awaitingMulligan;
    lastError = pvp.lastError;

    // The screen disables input while busy. Anything that is not this player's
    // decision is exactly that.
    busy = projection.stage != PvpStage.finished &&
        !_isMyDecision(projection);

    incomingAttackers = projection.stage == PvpStage.blockDeclaration
        ? projection.pendingAttackers
        : const [];
    if (projection.stage != PvpStage.blockDeclaration) {
      blockPlan = {};
      blockingSelectedAttacker = null;
    }
    if (projection.stage != PvpStage.attackDeclaration) {
      selectedAttackers.clear();
    }

    _queueAnimations();
    notifyListeners();
  }

  /// Turns server events into the cues the battle screen already animates.
  ///
  /// The projection alone would leave the board correct but lifeless: no lunge
  /// on an attack, no sound when a card lands. These are the same event kinds
  /// the single-player controller emits, so the screen treats both identically.
  void _queueAnimations() {
    for (final event in pvp.takeMatchEvents()) {
      switch (event.type) {
        case 'card_played':
          pendingEvents.add(
            DuelEvent('play', instanceId: _asInt(event.payload['instanceId'])),
          );
        case 'attack_declared':
          final ids = event.payload['attackerIds'];
          if (ids is List) {
            for (final id in ids) {
              pendingEvents.add(DuelEvent('attack', instanceId: _asInt(id)));
            }
          }
        case 'redraw':
          pendingEvents.add(const DuelEvent('draw'));
        case 'phase_changed':
          final active = event.payload['activePlayer'];
          if (active is String) {
            // Drawn from the viewer's chair, so the banner names the right side.
            final seat = PlayerId.values.asNameMap()[active];
            if (seat != null) {
              pendingEvents.add(
                DuelEvent('turnStart', player: _toLocalSeat(seat)),
              );
            }
          }
      }
    }
  }

  static int? _asInt(Object? value) => value is int
      ? value
      : value is num
          ? value.toInt()
          : null;

  /// Inverse of [_toServerSeat]: a seat named by the server, drawn locally.
  PlayerId _toLocalSeat(PlayerId server) => _toServerSeat(server);

  bool _isMyDecision(PvpProjection projection) {
    switch (projection.stage) {
      case PvpStage.waitingForReady:
      case PvpStage.mulligan:
        return true;
      case PvpStage.chainPriority:
        return projection.priority == projection.viewer;
      case PvpStage.blockDeclaration:
        // The defender assigns blocks.
        return projection.activePlayer != projection.viewer;
      case PvpStage.main:
      case PvpStage.attackDeclaration:
        return projection.activePlayer == projection.viewer;
      case PvpStage.finished:
        return false;
    }
  }

  DuelUiState _uiFor(PvpProjection projection) {
    if (projection.winner != null || projection.stage == PvpStage.finished) {
      return DuelUiState.gameOver;
    }
    switch (projection.stage) {
      case PvpStage.blockDeclaration:
        return projection.activePlayer == projection.viewer
            ? DuelUiState.enemyTurn
            : DuelUiState.playerBlocking;
      case PvpStage.chainPriority:
        return projection.priority == projection.viewer
            ? DuelUiState.playerResponse
            : DuelUiState.enemyTurn;
      case PvpStage.attackDeclaration:
        return projection.activePlayer == projection.viewer
            ? DuelUiState.playerCombat
            : DuelUiState.enemyTurn;
      case PvpStage.waitingForReady:
      case PvpStage.mulligan:
      case PvpStage.main:
        return projection.activePlayer == projection.viewer
            ? DuelUiState.playerMain
            : DuelUiState.enemyTurn;
      case PvpStage.finished:
        return DuelUiState.gameOver;
    }
  }

  /// The board is drawn with the viewer as p1; the server speaks real seats.
  PlayerId _toServerSeat(PlayerId local) {
    if (_seat == PlayerId.p1) return local;
    return local == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
  }

  // ── player actions out ────────────────────────────────────────────────

  @override
  void redrawHand() {
    if (!awaitingMulligan) return;
    pvp.redraw();
  }

  @override
  Future<void> confirmHand() async {
    if (!awaitingMulligan) return;
    await pvp.ready();
  }

  @override
  void playHandCard(int instanceId) {
    if (isGameOver || busy) return;
    final card = me.hand.where((c) => c.instanceId == instanceId).firstOrNull;
    if (card == null) return;

    final responding = ui == DuelUiState.playerBlocking ||
        ui == DuelUiState.playerResponse;
    if (responding && card.def.type != CardType.rite) return;

    lastError = null;

    // Aiming is a local decision; only the finished choice reaches the server.
    if (DuelController.chooseCount(card.def) > 0) {
      if (!hasLegalTarget(card.def)) {
        lastError = 'No legal targets for ${card.def.name}.';
        notifyListeners();
        return;
      }
      targetingId = instanceId;
      notifyListeners();
      return;
    }
    unawaited(_send(card, const []));
  }

  @override
  void selectUnitTarget(int unitInstanceId) {
    final card = _aimingCard();
    if (card == null) return;
    targetingId = null;
    unawaited(_send(card, [
      {'kind': 'unit', 'instanceId': unitInstanceId},
    ]));
  }

  @override
  void selectPlayerTarget(PlayerId pid) {
    final card = _aimingCard();
    if (card == null) return;
    if (!targetSpec(card.def).players) return;
    targetingId = null;
    unawaited(_send(card, [
      {'kind': 'player', 'playerId': _toServerSeat(pid).name},
    ]));
  }

  CardInstance? _aimingCard() {
    final id = targetingId;
    if (id == null) return null;
    final card = me.hand.where((c) => c.instanceId == id).firstOrNull;
    if (card == null) {
      targetingId = null;
      notifyListeners();
    }
    return card;
  }

  Future<void> _send(
    CardInstance card,
    List<Map<String, dynamic>> targets,
  ) async {
    notifyListeners();
    if (card.def.type == CardType.wellspring) {
      await pvp.playWellspring(card.instanceId);
      return;
    }

    await _payFor(card.def);
    switch (card.def.type) {
      case CardType.unit:
        await pvp.playUnit(card.instanceId, targets: targets);
      case CardType.wellspring:
        break;
      case CardType.rite:
      case CardType.ritual:
      case CardType.sigil:
      case CardType.relic:
        await pvp.cast(card.instanceId, targets: targets);
    }
  }

  /// Exerts Wellsprings until the cost can be paid.
  ///
  /// The duel screen has no "tap for Aether" control because the single-player
  /// controller quietly does this inside its own play routine. The online rules
  /// have no such shortcut: they reject a play the pool cannot cover, and
  /// exerting is a separate command. Without this the player could see an
  /// affordable card, tap it, and simply be refused.
  Future<void> _payFor(CardDef def) async {
    for (var guard = 0; guard < 20; guard++) {
      try {
        Game.payCost(def, me.aetherPool);
        return;
      } on StateError {
        final ready = me.arena
            .where((c) => c.def.type == CardType.wellspring && !c.exerted)
            .firstOrNull;
        // Nothing left to tap: let the server answer with the real reason
        // rather than inventing one here.
        if (ready == null) return;
        await pvp.exertForAether(ready.instanceId);
        if (pvp.lastError != null) return;
      }
    }
  }

  @override
  void enterCombat() {
    if (ui != DuelUiState.playerMain || isGameOver || isTargeting) return;
    pvp.nextPhase();
  }

  @override
  Future<void> confirmAttack() async {
    if (isGameOver) return;
    await pvp.declareAttackers(selectedAttackers.toList());
  }

  @override
  void confirmBlocks() {
    if (isGameOver) return;
    pvp.declareBlocks([
      for (final entry in blockPlan.entries)
        if (entry.value.isNotEmpty)
          {'attackerId': entry.key, 'blockerIds': entry.value},
    ]);
  }

  @override
  void passResponse() {
    pvp.passPriority();
  }

  @override
  Future<void> endTurn() async {
    if (isGameOver) return;

    // "End turn" means the turn passes, not "advance one phase". The
    // single-player controller loops until the seat changes; online it takes a
    // sequence, because leaving combat needs an explicit attack declaration.
    // Sending one nextPhase would have walked the player into Combat instead
    // of ending anything.
    final seat = pvp.projection?.viewer;
    for (var guard = 0; guard < 8; guard++) {
      final current = pvp.projection;
      if (current == null || current.activePlayer != seat) return;
      if (current.stage == PvpStage.finished) return;

      if (current.stage == PvpStage.attackDeclaration) {
        await pvp.declareAttackers(const []);
      } else if (current.stage == PvpStage.main) {
        await pvp.nextPhase();
      } else {
        // Someone else holds the decision; nothing to push.
        return;
      }
      if (pvp.lastError != null) return;
    }
  }

  @override
  void surrender() {
    pvp.concede();
  }

  /// The inherited opening sequence deals a local hand and starts the AI.
  /// Online, the server has already done all of that.
  @override
  Future<void> begin() async {}
}
