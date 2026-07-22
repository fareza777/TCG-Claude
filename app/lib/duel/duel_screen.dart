import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/audio_manager.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';
import 'duel_controller.dart';

class DuelScreen extends StatefulWidget {
  final DuelController controller;
  final String enemyName;

  const DuelScreen(
      {super.key, required this.controller, this.enemyName = 'Ashen Warlord'});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shake;
  final List<_FloatingText> _floats = [];
  int _floatSeq = 0;

  DuelController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    c.addListener(_onUpdate);
    // begin() is triggered after the mulligan (see _mulliganOverlay).
  }

  int _flashSeq = 0;
  bool _flashTop = false;

  @override
  void dispose() {
    c.removeListener(_onUpdate);
    _shake.dispose();
    super.dispose();
  }

  void _onUpdate() {
    final audio = AudioManager.instance;
    for (final e in c.takeEvents()) {
      switch (e.kind) {
        case 'play':
          audio.cardPlay();
        case 'attack':
          audio.attack();
          final id = e.instanceId;
          if (id != null) {
            _lunging.add(id);
            Future.delayed(const Duration(milliseconds: 460), () {
              if (mounted) setState(() => _lunging.remove(id));
            });
          }
        case 'death':
          audio.damage();
          _spawnFloat('✕', 0.5, const Color(0xFFB03A3A));
        case 'unitDamaged':
          audio.damage();
          final id = e.instanceId;
          if (id != null) {
            _hitUnits.add(id);
            Future.delayed(const Duration(milliseconds: 520), () {
              if (mounted) setState(() => _hitUnits.remove(id));
            });
          }
          _spawnFloat('-${e.amount}',
              e.player == DuelController.enemy ? 0.28 : 0.66,
              AppTheme.danger);
        case 'proc':
          if (e.label != null) {
            _spawnFloat(e.label!, 0.42, const Color(0xFFE6CE96));
          }
        case 'turnStart':
          _turnBanner = e.player == DuelController.human
              ? 'YOUR TURN'
              : 'ENEMY TURN';
          _turnBannerSeq++;
          final seq = _turnBannerSeq;
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && seq == _turnBannerSeq) {
              setState(() => _turnBanner = null);
            }
          });
        case 'discard':
          _spawnDiscard(e.player == DuelController.enemy);
        case 'damagePlayer':
          if ((e.amount ?? 0) > 0) {
            audio.damage();
            _spawnFloat('-${e.amount}',
                e.player == DuelController.human ? 0.78 : 0.16,
                AppTheme.danger);
            _flashSeq++;
            _flashTop = e.player == DuelController.enemy;
            if (e.player == DuelController.human && !MotionPrefs.reduce) {
              _shake.forward(from: 0);
            }
          }
      }
    }
    if (c.isGameOver && !_endSoundPlayed) {
      _endSoundPlayed = true;
      c.playerWon ? audio.victory() : audio.defeat();
    }
    if (mounted) setState(() {});
  }

  bool _endSoundPlayed = false;
  final Set<int> _lunging = {};
  final Set<int> _hitUnits = {}; // units flashing from spell damage
  String? _turnBanner; // "YOUR TURN" / "ENEMY TURN" sweep
  int _turnBannerSeq = 0;
  final List<_DiscardFly> _discards = [];
  int _discardSeq = 0;

  void _spawnDiscard(bool fromTop) {
    final id = _discardSeq++;
    setState(() => _discards.add(_DiscardFly(id, fromTop)));
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _discards.removeWhere((d) => d.id == id));
    });
  }

  void _spawnFloat(String text, double yFactor, Color color) {
    final id = _floatSeq++;
    setState(() => _floats.add(_FloatingText(id, text, yFactor, color)));
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Container(
          color: AppTheme.bgBottom,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/ui/battle_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox()),
              // scrim: darken overall + stronger at top and bottom for text
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC0B0D12),
                      Color(0x730B0D12),
                      Color(0xE60B0D12),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _enemyBar(),
                    _phaseBar(),
                    if (c.enemyCastName != null) _enemyCastBanner(),
                    if (c.playerCastName != null) _playerCastBanner(),
                    if (c.attuneMode) _attuneBanner(),
                    if (c.isTargeting) _targetingBanner(),
                    if (c.ui == DuelUiState.playerBlocking) _blockingBanner(),
                    if (c.ui == DuelUiState.playerResponse) _responseBanner(),
                    Expanded(child: _battlefield()),
                    _actionBar(),
                    _hand(),
                  ],
                ),
                _hitFlash(),
                ..._floats.map(_floatWidget),
                ..._discards.map(_discardWidget),
                if (_turnBanner != null) _turnBannerOverlay(),
                if (c.awaitingMulligan) _mulliganOverlay(),
                if (c.isGameOver) _gameOverOverlay(),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  // ── top: enemy status ────────────────────────────────────────────────
  Widget _enemyBar() {
    final foe = c.foe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: c.isTargeting &&
                    c.targetingDef != null &&
                    c.targetSpec(c.targetingDef!).players
                ? () => c.selectPlayerTarget(DuelController.enemy)
                : null,
            child: _healthOrb(foe.health, DominionStyle.of(Dominion.pyre).glow,
                targetable: c.isTargeting &&
                    c.targetingDef != null &&
                    c.targetSpec(c.targetingDef!).players),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.enemyName,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text('Hand ${foe.hand.length} · Deck ${foe.deck.length}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const Spacer(),
          if (c.ui == DuelUiState.enemyTurn)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          GestureDetector(
            onTap: _showHistory,
            child: Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.panelBorder.withValues(alpha: 0.7)),
              ),
              child: const Icon(Icons.history,
                  size: 15, color: AppTheme.textMuted),
            ),
          ),
          if (!c.isGameOver)
            GestureDetector(
              onTap: _confirmSurrender,
              child: Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.flag,
                    size: 15, color: AppTheme.danger),
              ),
            ),
          _phaseChip(),
        ],
      ),
    );
  }

  void _confirmSurrender() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Surrender?',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: const Text('Concede this duel and return? You will lose.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep fighting'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.surrender();
            },
            child: const Text('Surrender',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Battle log',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: c.history.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    c.history[c.history.length - 1 - i],
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12, height: 1.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF6FB0DC).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6FB0DC).withValues(alpha: 0.7)),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt, size: 15, color: Color(0xFF6FB0DC)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Response window — cast a Rite in reply, or Pass.',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockingBanner() {
    final sel = c.blockingSelectedAttacker;
    final selName = sel == null
        ? null
        : c.foe.arena
            .where((u) => u.instanceId == sel)
            .map((u) => u.def.name)
            .firstOrNull;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF7FE0A8).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7FE0A8).withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, size: 14, color: Color(0xFF7FE0A8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selName == null
                  ? 'Enemy attacks! Tap a red attacker, then your Units to block. You may also cast a Rite in response — or Take the hit.'
                  : 'Blocking $selName — tap your Units to assign blockers.',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetingBanner() {
    final def = c.targetingDef;
    final spec = def == null
        ? const TargetSpec(units: true, players: false)
        : c.targetSpec(def);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed, size: 14, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              def == null
                  ? 'Choose a target'
                  : 'Choose a target for ${def.name}'
                      '${spec.players ? ' — tap a unit or a player' : ' — tap a unit'}',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: c.cancelTargeting,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseChip() {
    final (label, color) = switch (c.ui) {
      DuelUiState.playerMain => ('Your Main', const Color(0xFF6FB0DC)),
      DuelUiState.playerCombat => ('Combat', AppTheme.danger),
      DuelUiState.playerBlocking => ('Declare Blocks', const Color(0xFF7FE0A8)),
      DuelUiState.playerResponse => ('Respond', const Color(0xFF6FB0DC)),
      DuelUiState.enemyTurn => ('Enemy Turn', const Color(0xFFB48AD1)),
      DuelUiState.gameOver => ('Game Over', AppTheme.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── phase bar (MTG-style turn structure) ─────────────────────────────
  Widget _phaseBar() {
    const phases = [
      (Phase.refresh, 'Untap'),
      (Phase.draw, 'Draw'),
      (Phase.main1, 'Main 1'),
      (Phase.combat, 'Combat'),
      (Phase.main2, 'Main 2'),
      (Phase.end, 'End'),
    ];
    final current = c.state.phase;
    final enemyActive = c.state.activePlayer == DuelController.enemy;
    final accent = enemyActive
        ? DominionStyle.of(Dominion.gloom).glow
        : const Color(0xFFC9A86A);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.panelBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            enemyActive ? Icons.smart_toy_outlined : Icons.person_outline,
            size: 13,
            color: accent,
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0)
              Container(
                width: 10,
                height: 1,
                color: AppTheme.panelBorder.withValues(alpha: 0.6),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: phases[i].$1 == current
                    ? accent.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: phases[i].$1 == current
                      ? accent
                      : Colors.transparent,
                ),
              ),
              child: Text(
                phases[i].$2,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  fontWeight: phases[i].$1 == current
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: phases[i].$1 == current
                      ? Colors.white
                      : AppTheme.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── middle: both arenas ──────────────────────────────────────────────
  Widget _battlefield() {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
        Column(
          children: [
            Expanded(child: _arenaRow(c.foe, enemySide: true)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppTheme.panelBorder.withValues(alpha: 0.9),
                  Colors.transparent,
                ]),
              ),
            ),
            Expanded(child: _arenaRow(c.me, enemySide: false)),
          ],
        ),
      ],
    );
  }

  Widget _arenaRow(PlayerState p, {required bool enemySide}) {
    final units = p.arena
        .where((u) => u.def.type != CardType.wellspring)
        .toList();
    final wells = p.arena
        .where((u) => u.def.type == CardType.wellspring)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // wellsprings stack indicator
          _wellspringPile(wells, enemySide),
          const SizedBox(width: 8),
          Expanded(
            child: units.isEmpty
                ? Center(
                    child: Text(
                      enemySide ? '' : 'Empty arena — summon a Unit',
                      style: const TextStyle(
                          color: Color(0x33FFFFFF), fontSize: 11),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Extra top room so lifted cards + A1/A2 tags never clip.
                    padding: const EdgeInsets.only(top: 20, bottom: 6),
                    child: Row(
                      children: [
                        for (final u in units)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3),
                            child: _arenaUnit(u, enemySide),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          _ruinsPile(p, enemySide),
        ],
      ),
    );
  }

  /// Graveyard indicator — tap to inspect.
  Widget _ruinsPile(PlayerState p, bool enemySide) {
    final count = p.ruins.length;
    return GestureDetector(
      onTap: count == 0 ? null : () => _showRuins(p, enemySide),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: count > 0
                      ? AppTheme.panelBorder
                      : AppTheme.panelBorder.withValues(alpha: 0.35),
                  width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cyclone,
                    size: 13,
                    color: count > 0
                        ? AppTheme.textMuted
                        : AppTheme.textMuted.withValues(alpha: 0.35)),
                Text('$count',
                    style: TextStyle(
                        color: count > 0
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('Ruins',
              style: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.8),
                  fontSize: 9)),
        ],
      ),
    );
  }

  void _showRuins(PlayerState p, bool enemySide) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(enemySide ? 'Enemy ruins' : 'Your ruins',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                childAspectRatio: 63 / 88,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final card in p.ruins.reversed)
                    GestureDetector(
                      onTap: () => _zoom(card.def),
                      child: CardWidget(def: card.def, width: 80),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wellspringPile(List<CardInstance> wells, bool enemySide) {
    if (wells.isEmpty) return const SizedBox(width: 34);
    final ready = wells.where((w) => !w.exerted).length;
    final style = DominionStyle.ofCard(wells.first.def);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: style.frame),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: ready > 0
                    ? style.glow.withValues(alpha: 0.9)
                    : Colors.black45,
                width: 1.4),
            boxShadow: ready > 0
                ? [
                    BoxShadow(
                        color: style.glow.withValues(alpha: 0.35),
                        blurRadius: 8)
                  ]
                : null,
          ),
          child: Text('$ready/${wells.length}',
              style: TextStyle(
                  color: style.glow,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        Text('Aether',
            style: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.8),
                fontSize: 9)),
      ],
    );
  }

  Widget _arenaUnit(CardInstance u, bool enemySide) {
    final blocking = c.ui == DuelUiState.playerBlocking;
    final selected = c.selectedAttackers.contains(u.instanceId);
    final aiming = c.isTargeting && u.def.type == CardType.unit;
    // The enemy is casting a spell aimed at this unit — show a red reticle.
    final beingTargeted = c.enemyCastTargetId == u.instanceId;
    // The player is casting a spell aimed at this unit — gold reticle.
    final beingPlayerTargeted = c.playerCastTargetId == u.instanceId;
    final selectable = !aiming &&
        !blocking &&
        !enemySide &&
        c.ui == DuelUiState.playerCombat &&
        u.canAttack &&
        !u.def.keywords.contains(Keyword.bulwark);

    // Blocking-mode roles.
    final isIncomingAttacker =
        blocking && enemySide && c.incomingAttackers.contains(u.instanceId);
    final isSelectedAttacker =
        isIncomingAttacker && c.blockingSelectedAttacker == u.instanceId;
    final canBeBlocker = blocking &&
        !enemySide &&
        u.def.type == CardType.unit &&
        !u.exerted;
    final blocksAttacker = c.blockerAssignedTo(u.instanceId);
    // Index label (A1, A2...) for each incoming attacker.
    int? attackerIndex;
    if (blocking) {
      final idx = c.incomingAttackers.indexOf(
          isIncomingAttacker ? u.instanceId : (blocksAttacker ?? -1));
      if (idx >= 0) attackerIndex = idx + 1;
    }

    final style = DominionStyle.ofCard(u.def);

    VoidCallback? onTap;
    if (aiming && u.def.type == CardType.unit) {
      onTap = () => c.selectUnitTarget(u.instanceId);
    } else if (isIncomingAttacker) {
      onTap = () => c.selectAttackerToBlock(u.instanceId);
    } else if (canBeBlocker) {
      onTap = () => c.assignBlocker(u.instanceId);
    } else if (selectable) {
      onTap = () => c.toggleAttacker(u.instanceId);
    }

    final lift = selected || isSelectedAttacker;
    final highlight = aiming
        ? AppTheme.danger
        : selected
            ? AppTheme.danger
            : isSelectedAttacker
                ? const Color(0xFFE3B341)
                : isIncomingAttacker
                    ? AppTheme.danger.withValues(alpha: 0.7)
                    : blocksAttacker != null
                        ? const Color(0xFF7FE0A8)
                        : (selectable || canBeBlocker)
                            ? style.glow
                            : null;

    return TweenAnimationBuilder<double>(
      key: ValueKey('arena${u.instanceId}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.55 + 0.45 * t.clamp(0, 1),
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _zoom(u.def),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Duration(
                  milliseconds: _lunging.contains(u.instanceId) ? 150 : 180),
              curve: Curves.easeOut,
              // Lunge toward the opponent when attacking; else settle/lift.
              transform: Matrix4.translationValues(
                  0,
                  _lunging.contains(u.instanceId)
                      ? (enemySide ? 30 : -30)
                      : (lift ? -8 : 0),
                  0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: _lunging.contains(u.instanceId)
                    ? [
                        BoxShadow(
                            color: AppTheme.danger.withValues(alpha: 0.65),
                            blurRadius: 18,
                            spreadRadius: 2)
                      ]
                    : highlight == null
                    ? null
                    : [
                        BoxShadow(
                            color: highlight.withValues(
                                alpha: isSelectedAttacker ? 0.6 : 0.4),
                            blurRadius: isSelectedAttacker ? 16 : 11,
                            spreadRadius: isSelectedAttacker ? 2 : 0)
                      ],
              ),
              child: CardWidget(
                def: u.def,
                width: 84,
                exerted: u.exerted,
                plusCounters: u.plusCounters,
                damage: u.damage,
              ),
            ),
          // brief red flash when this unit is hit by a spell
          if (_hitUnits.contains(u.instanceId))
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.danger.withValues(alpha: 0.3),
                    border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.9),
                        width: 2),
                  ),
                ),
              ),
            ),
          // player spell targeting reticle (gold)
          if (beingPlayerTargeted) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE3B341).withValues(alpha: t),
                          width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFE3B341)
                                .withValues(alpha: 0.5 * t),
                            blurRadius: 16,
                            spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -12,
              right: -8,
              child: Icon(Icons.gps_fixed, size: 22, color: Color(0xFFE3B341)),
            ),
          ],
          // enemy spell targeting reticle
          if (beingTargeted) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.danger.withValues(alpha: t),
                          width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.danger.withValues(alpha: 0.5 * t),
                            blurRadius: 18,
                            spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -12,
              right: -8,
              child: Icon(Icons.gps_fixed, size: 22, color: AppTheme.danger),
            ),
          ],
          // attacker index tag / blocker-target tag
          if (blocking && isIncomingAttacker)
            Positioned(
              top: -6,
              left: -4,
              child: _tag('A$attackerIndex', AppTheme.danger),
            ),
          if (blocking && blocksAttacker != null)
            Positioned(
              top: -6,
              left: -4,
              child: _tag('▶A$attackerIndex', const Color(0xFF2E6B2A)),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shown while the enemy is resolving a spell, so the play is
  /// legible instead of a unit silently disappearing.
  Widget _enemyCastBanner() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('cast${c.enemyCastName}${c.enemyCastTargetId}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * -8), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.danger.withValues(alpha: 0.28),
            AppTheme.danger.withValues(alpha: 0.12),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.75)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high, size: 15, color: AppTheme.danger),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                c.enemyCastTargetId != null
                    ? 'Enemy casts ${c.enemyCastName}  →  your unit'
                    : c.enemyCastAtPlayer
                        ? 'Enemy casts ${c.enemyCastName}  →  YOU'
                        : 'Enemy casts ${c.enemyCastName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFFFD9D2),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCastBanner() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('pcast${c.playerCastName}${c.playerCastTargetId}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFC9A86A).withValues(alpha: 0.26),
            const Color(0xFFC9A86A).withValues(alpha: 0.10),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC9A86A).withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high, size: 15, color: Color(0xFFE6CE96)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                c.playerCastTargetId != null
                    ? 'You cast ${c.playerCastName}  →  target'
                    : 'You cast ${c.playerCastName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFF0E4C0),
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attuneBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB48AD1).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB48AD1).withValues(alpha: 0.7)),
      ),
      child: const Text(
        'Tap a card to Attune it into a generic Wellspring (uses your land drop)',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Color(0xFFE0CCF2), fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900)),
    );
  }

  // ── action bar ───────────────────────────────────────────────────────
  Widget _actionBar() {
    final me = c.me;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: c.isTargeting &&
                    c.targetingDef != null &&
                    c.targetSpec(c.targetingDef!).players
                ? () => c.selectPlayerTarget(DuelController.human)
                : null,
            child: _healthOrb(me.health, AppTheme.health,
                targetable: c.enemyCastAtPlayer ||
                    (c.isTargeting &&
                        c.targetingDef != null &&
                        c.targetSpec(c.targetingDef!).players)),
          ),
          const SizedBox(width: 8),
          Text('Deck ${me.deck.length}',
              style:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const Spacer(),
          if (c.lastError != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(c.lastError!,
                  style:
                      const TextStyle(color: AppTheme.danger, fontSize: 11)),
            ),
          if (c.ui == DuelUiState.playerMain) ...[
            if (c.attuneMode)
              _btn('✕ Cancel', AppTheme.textMuted, c.toggleAttuneMode)
            else if (c.canAttune) ...[
              _btn('⤓ Attune', const Color(0xFFB48AD1), c.toggleAttuneMode),
              const SizedBox(width: 8),
            ],
            _btn('⚔ Combat', AppTheme.danger, c.enterCombat),
            const SizedBox(width: 8),
            _btn('End Turn', const Color(0xFF6FB0DC), () => c.endTurn()),
          ] else if (c.ui == DuelUiState.playerCombat) ...[
            if (c.eligibleAttackers.isNotEmpty) ...[
              _btn('All', const Color(0xFFC9A86A), c.toggleAttackAll),
              const SizedBox(width: 8),
            ],
            _btn(
                c.selectedAttackers.isEmpty
                    ? 'Skip Attack'
                    : 'Attack (${c.selectedAttackers.length})',
                AppTheme.danger,
                () => c.confirmAttack()),
          ] else if (c.ui == DuelUiState.playerBlocking) ...[
            if (c.blockPlan.isNotEmpty) ...[
              _btn('Clear', AppTheme.textMuted, c.clearBlocks),
              const SizedBox(width: 8),
            ],
            _btn(
                c.blockPlan.isEmpty ? 'Take the hit' : 'Confirm blocks',
                const Color(0xFF7FE0A8),
                c.confirmBlocks),
          ] else if (c.ui == DuelUiState.playerResponse) ...[
            _btn('Pass', const Color(0xFF6FB0DC), c.passResponse),
          ],
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.32),
                color.withValues(alpha: 0.14)
              ]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _healthOrb(int hp, Color color, {bool targetable = false}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.10)
        ]),
        border: Border.all(
            color: targetable
                ? AppTheme.danger
                : color.withValues(alpha: 0.8),
            width: targetable ? 2.4 : 1.6),
        boxShadow: [
          BoxShadow(
              color: targetable
                  ? AppTheme.danger.withValues(alpha: 0.6)
                  : color.withValues(alpha: 0.3),
              blurRadius: targetable ? 16 : 10)
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Text('$hp',
            key: ValueKey(hp),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ── hand fan ─────────────────────────────────────────────────────────
  Widget _hand() {
    final hand = c.me.hand;
    const cardW = 96.0;
    return SizedBox(
      height: 156,
      child: LayoutBuilder(
        builder: (context, box) {
          final n = hand.length;
          if (n == 0) return const SizedBox();
          final spread = math.min(cardW * 0.72, (box.maxWidth - cardW - 24) / math.max(1, n - 1));
          final totalW = spread * (n - 1) + cardW;
          final x0 = (box.maxWidth - totalW) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: x0 + i * spread,
                  top: 18 +
                      (n > 1
                          ? 14.0 *
                              math
                                  .pow(
                                      (i - (n - 1) / 2).abs() /
                                          ((n - 1) / 2 + 0.001),
                                      2)
                                  .toDouble()
                          : 0.0),
                  child: _handCard(hand[i], i, n, cardW),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _handCard(CardInstance card, int i, int n, double w) {
    final affordable = card.def.type == CardType.wellspring
        ? !c.me.playedWellspringThisTurn
        : c.canAfford(card.def);
    final canRespond = (c.ui == DuelUiState.playerBlocking ||
            c.ui == DuelUiState.playerResponse) &&
        card.def.type == CardType.rite;
    final playable = (c.ui == DuelUiState.playerMain || canRespond) &&
        affordable &&
        !c.isTargeting;
    final angle = n > 1 ? (i - (n - 1) / 2) * 0.035 : 0.0;
    final style = DominionStyle.ofCard(card.def);
    // Draw animation: a newly-arrived card (new key) slides up + fades in
    // from the deck instead of popping in instantly.
    return TweenAnimationBuilder<double>(
      key: ValueKey('hand${card.instanceId}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 46 * (1 - t)),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
      ),
      child: GestureDetector(
      onTap: playable ? () => c.playHandCard(card.instanceId) : null,
      onLongPress: () => _zoom(card.def),
      child: Transform.rotate(
        angle: angle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform:
              Matrix4.translationValues(0, playable ? -6 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: playable
                ? [
                    BoxShadow(
                        color: style.glow.withValues(alpha: 0.4),
                        blurRadius: 12)
                  ]
                : null,
          ),
          child: Opacity(
            opacity: playable || c.ui != DuelUiState.playerMain ? 1 : 0.55,
            child: CardWidget(def: card.def, width: w),
          ),
        ),
      ),
      ),
    );
  }

  void _zoom(CardDef def) => showCardZoom(context, def);

  Widget _discardWidget(_DiscardFly d) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInCubic,
          builder: (context, t, _) {
            // Fly from the discarding player's side toward the Ruins pile
            // (right edge), rotating and fading out.
            final startY = d.fromTop ? -0.55 : 0.75;
            final endY = d.fromTop ? -0.35 : 0.35;
            final x = -0.1 + t * 1.0;
            final y = startY + (endY - startY) * t;
            return Align(
              alignment: Alignment(x.clamp(-1.0, 1.0), y),
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: t * 1.2,
                  child: Container(
                    width: 40,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF232A44), Color(0xFF10141F)],
                      ),
                      border: Border.all(
                          color: const Color(0xFFB9995C)
                              .withValues(alpha: 0.7)),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFFB9995C), size: 18),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _floatWidget(_FloatingText f) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
          builder: (context, t, _) => Align(
            alignment: Alignment(0.55, (f.yFactor * 2 - 1) - t * 0.18),
            child: Opacity(
              opacity: 1 - t,
              child: Text(f.text,
                  style: TextStyle(
                      color: f.color,
                      fontSize: 30 + 8 * (1 - t),
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8)
                      ])),
            ),
          ),
        ),
      ),
    );
  }

  Widget _turnBannerOverlay() {
    final isYou = _turnBanner == 'YOUR TURN';
    final color = isYou ? const Color(0xFF7FE0A8) : AppTheme.danger;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_turnBannerSeq),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, t, _) {
              // slide in from the left, hold, fade near the end
              final dx = (1 - t) * -120;
              final op = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15);
              return Opacity(
                opacity: op.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        color.withValues(alpha: 0.22),
                        color.withValues(alpha: 0.22),
                        Colors.transparent,
                      ]),
                      border: Border(
                        top: BorderSide(color: color.withValues(alpha: 0.7)),
                        bottom: BorderSide(color: color.withValues(alpha: 0.7)),
                      ),
                    ),
                    child: Text(
                      _turnBanner!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: Colors.white,
                        fontSize: 26,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: color, blurRadius: 18),
                          const Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hitFlash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_flashSeq),
          tween: Tween(begin: _flashSeq == 0 ? 0 : 1, end: 0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          builder: (context, t, _) => t <= 0.01
              ? const SizedBox()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, _flashTop ? -0.85 : 0.85),
                      radius: 0.9,
                      colors: [
                        AppTheme.danger.withValues(alpha: 0.42 * t),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _mulliganOverlay() {
    final hand = c.me.hand;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('OPENING HAND',
                style: TextStyle(
                    color: Color(0xFFE6CE96),
                    fontSize: 16,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                c.firstPlayer == DuelController.human
                    ? 'You are on the play.'
                    : 'You are on the draw (+1 card).',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final card in hand)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onLongPress: () => _zoom(card.def),
                          child: CardWidget(def: card.def, width: 120),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!c.mulliganUsed)
                  _btn('↻ Redraw once', const Color(0xFF6FB0DC),
                      c.redrawHand),
                if (!c.mulliganUsed) const SizedBox(width: 12),
                _btn('Keep this hand', const Color(0xFF7FE0A8),
                    () => c.confirmHand()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    final won = c.playerWon;
    final color = won ? const Color(0xFFE3B341) : AppTheme.danger;
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black.withValues(alpha: 0.72)),
          // radiant burst behind the banner
          IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (context, t, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.4 + t * 0.9,
                    colors: [
                      color.withValues(alpha: 0.35 * (1 - t * 0.3)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Text(
                  won ? 'VICTORY' : 'DEFEAT',
                  style: TextStyle(
                      color: color,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 24)
                      ]),
                ),
              ),
              const SizedBox(height: 18),
              _btn('Continue', const Color(0xFF6FB0DC),
                  () => Navigator.of(context).pop(c.playerWon)),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

class _FloatingText {
  final int id;
  final String text;
  final double yFactor;
  final Color color;
  _FloatingText(this.id, this.text, this.yFactor, this.color);
}

class _DiscardFly {
  final int id;
  final bool fromTop;
  _DiscardFly(this.id, this.fromTop);
}

/// Subtle procedural battle mat: two facing arena rings with faint runes.
class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // central seam glow
    final seam = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x22C9A86A),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, cy - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, cy - 30, size.width, 60), seam);

    // two facing elliptical arenas (enemy top, player bottom)
    for (final sign in [-1.0, 1.0]) {
      final zoneY = cy + sign * size.height * 0.24;
      for (var i = 0; i < 3; i++) {
        final rx = size.width * (0.30 - i * 0.06);
        final ry = size.height * (0.11 - i * 0.02);
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFC9A86A)
              .withValues(alpha: 0.06 - i * 0.015);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx, zoneY), width: rx * 2, height: ry * 2),
            ring);
      }
    }

    // faint radial vignette to focus the center
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
        stops: const [0.6, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => false;
}
