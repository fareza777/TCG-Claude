import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../services/audio_manager.dart';
import '../theme.dart';

/// Animated coin flip that decides who takes the first turn in a skirmish.
/// Returns [PlayerId.p1] (you) or [PlayerId.p2] (enemy).
Future<PlayerId> showCoinFlip(BuildContext context) async {
  final result = math.Random().nextBool() ? PlayerId.p1 : PlayerId.p2;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (_) => _CoinFlipDialog(result: result),
  );
  return result;
}

class _CoinFlipDialog extends StatefulWidget {
  final PlayerId result;
  const _CoinFlipDialog({required this.result});

  @override
  State<_CoinFlipDialog> createState() => _CoinFlipDialogState();
}

class _CoinFlipDialogState extends State<_CoinFlipDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _ctrl.forward();
    _ctrl.addStatusListener((s) async {
      if (s == AnimationStatus.completed) {
        setState(() => _revealed = true);
        widget.result == PlayerId.p1
            ? AudioManager.instance.reward()
            : AudioManager.instance.attack();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final youWin = widget.result == PlayerId.p1;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              // several fast spins that ease to a stop
              final spins = Curves.easeOut.transform(_ctrl.value) * 8;
              final angle = spins * math.pi;
              final showHeads = (angle % (2 * math.pi)) < math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(angle),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: showHeads
                        ? const [Color(0xFFF4E2A6), Color(0xFFC9A24A)]
                        : const [Color(0xFFCFD6DE), Color(0xFF8A93A0)]),
                    border: Border.all(
                        color: const Color(0xFF6E5527), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 14)
                    ],
                  ),
                  child: Icon(
                      showHeads ? Icons.wb_sunny : Icons.dark_mode,
                      size: 56,
                      color: const Color(0xFF3A2C07)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            _revealed
                ? (youWin ? 'YOU GO FIRST' : 'ENEMY GOES FIRST')
                : 'FLIPPING...',
            style: TextStyle(
              color: _revealed
                  ? (youWin ? const Color(0xFF7FE0A8) : AppTheme.danger)
                  : AppTheme.textPrimary,
              fontSize: 18,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
