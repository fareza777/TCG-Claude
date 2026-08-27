import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../duel/duel_controller.dart';
import '../duel/duel_screen.dart';
import '../duel/scenario.dart';
import '../theme.dart';
import 'tutorial_coach.dart';

/// A real duel with a coach on top of it.
///
/// The battle is genuine — same engine, same screen, same rules — because a
/// fake one teaches fake lessons. Only the difficulty is bent: a weak opponent
/// on low Health, so a first-timer fumbling through the first three turns
/// still gets to see themselves win.
class PracticeBattleScreen extends StatefulWidget {
  final CardLibrary library;

  const PracticeBattleScreen({super.key, required this.library});

  @override
  State<PracticeBattleScreen> createState() => _PracticeBattleScreenState();
}

class _PracticeBattleScreenState extends State<PracticeBattleScreen> {
  late final DuelController _controller;
  final _coach = TutorialCoach();

  @override
  void initState() {
    super.initState();
    _controller = DuelController(
      playerDeck: widget.library.buildStarterDeck('VERDANCE'),
      enemyDeck: widget.library.buildStarterDeck('PYRE'),
      scenario: const BattleScenario(
        enemyHealth: 10,
        objective: 'Learn the shape of a turn.',
        specialRules: [
          'A practice opponent, at 10 Health.',
          'Nothing here is recorded — lose as often as you like.',
        ],
      ),
      // The gentlest opponent there is. This fight exists to be understood,
      // not survived.
      aiTier: AiTier.greedy,
    );
    _controller.addListener(_reobserve);
    _reobserve();
  }

  void _reobserve() {
    _coach.observe(_controller.state, DuelController.human);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_reobserve);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DuelScreen(
        controller: _controller,
        enemyName: 'Practice Foe',
        statusBanner: _coachBanner(),
      );

  /// The instruction strip. Rendered in the slot PvP uses for its online
  /// status, so the duel layout itself needs no change at all.
  Widget _coachBanner() {
    final prompt = _coach.prompt;
    final done = _coach.isComplete;
    final accent = done ? const Color(0xFF7FE0A8) : const Color(0xFFC9A86A);

    return Semantics(
      liveRegion: true,
      label: '${prompt.title}. ${prompt.body}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(done ? Icons.check_circle_outline : Icons.school,
                size: 17, color: accent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prompt.title,
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(prompt.body,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
