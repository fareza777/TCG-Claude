import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../duel/duel_controller.dart';
import '../duel/duel_screen.dart';
import '../theme.dart';
import 'pvp_duel_controller.dart';

/// The shared battle screen with an online status strip laid over it.
///
/// Offline you always know where you are: the AI acts in front of you, in
/// paced beats. Online the opponent is silent, so the same board can leave a
/// player unsure whether it is their move, whose phase it is, or whether the
/// match is still alive at all. This strip answers those three questions
/// without changing a line of the duel screen it sits on.
class PvpBattleScreen extends StatelessWidget {
  const PvpBattleScreen({super.key, required this.controller});

  final PvpDuelController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DuelScreen(controller: controller, enemyName: 'Opponent'),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: _PvpStatusStrip(controller: controller),
          ),
        ),
      ],
    );
  }
}

class _PvpStatusStrip extends StatefulWidget {
  const _PvpStatusStrip({required this.controller});

  final PvpDuelController controller;

  @override
  State<_PvpStatusStrip> createState() => _PvpStatusStripState();
}

class _PvpStatusStripState extends State<_PvpStatusStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    // The countdown has to move on its own; the controller only speaks when
    // the server does.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  static const _phaseNames = {
    Phase.refresh: 'UNTAP',
    Phase.draw: 'DRAW',
    Phase.main1: 'MAIN 1',
    Phase.combat: 'COMBAT',
    Phase.main2: 'MAIN 2',
    Phase.end: 'END',
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.isGameOver) return const SizedBox.shrink();

    final mine = c.state.activePlayer == DuelController.human;
    final waiting = c.busy;
    final remaining = c.turnRemaining;
    final low = remaining.inSeconds <= 20;

    final accent = mine ? const Color(0xFF8FE3FF) : const Color(0xFFE3B341);
    final label = mine ? 'YOUR TURN' : "OPPONENT'S TURN";

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A quiet pulse while the opponent thinks, so a still board still
            // reads as "connected" rather than "stuck".
            if (waiting)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              Icon(Icons.circle, size: 9, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            _dot(),
            Text(
              _phaseNames[c.state.phase] ?? c.state.phase.name.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            _dot(),
            Text(
              _clock(remaining),
              style: TextStyle(
                color: low ? AppTheme.danger : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7),
        child: Text('·',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      );

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
