import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../duel/duel_controller.dart';
import '../duel/duel_screen.dart';
import '../duel/scenario.dart';
import '../services/audio_manager.dart';
import '../services/haptics.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';
import 'daily_gauntlet.dart';
import 'gauntlet_reward.dart';

/// The daily challenge: one seeded fight, one attempt, the same for everyone.
class GauntletScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;

  const GauntletScreen({super.key, required this.library, required this.save});

  @override
  State<GauntletScreen> createState() => _GauntletScreenState();
}

class _GauntletScreenState extends State<GauntletScreen> {
  late GauntletDay _day;
  GauntletReward? _justEarned;
  int _streakAfter = 0;

  SaveService get save => widget.save;

  @override
  void initState() {
    super.initState();
    _day = DailyGauntlet.build(
        widget.library, DailyGauntlet.idFor(DateTime.now()));
  }

  bool get _done => save.gauntletDoneFor(_day.id);
  bool get _resumable => save.gauntletResumableFor(_day.id);

  String get _timeLeft {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final left = midnight.difference(now);
    if (left.inHours >= 1) return 'Resets in ${left.inHours}h';
    return 'Resets in ${left.inMinutes}m';
  }

  List<CardDef> get _loanDeck => [
        for (final entry in _day.deck.entries)
          for (var i = 0; i < entry.value; i++) widget.library.card(entry.key),
      ];

  // ── playing ───────────────────────────────────────────────────────────

  Future<void> _play() async {
    Haptics.commit();
    // Recorded before a single card is seen. Backing out of a bad-looking
    // opening must not be a way to reroll the day.
    await save.beginGauntlet(_day.id);
    if (!mounted) return;

    final controller = DuelController(
      playerDeck: _loanDeck,
      enemyDeck: widget.library.buildStarterDeck(_day.foeDominion.name.toUpperCase()),
      scenario: BattleScenario(
        playerHealth: _day.playerHealth,
        enemyHealth: _day.foeHealth,
        enemyBoard: _day.foeBoard,
        objective: _day.shape,
        specialRules: [
          'One attempt. The same challenge for every player today.',
          if (_day.foeBoard.isNotEmpty)
            'They open with ${_day.foeBoard.length} unit'
                '${_day.foeBoard.length == 1 ? '' : 's'} already in play.',
        ],
      ),
      aiTier: _day.foeTier,
      // The day is the seed. This is what makes every player's board identical.
      seed: _day.seed,
    );

    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DuelScreen(
        controller: controller,
        enemyName: 'Today\'s Champion',
      ),
    ));
    if (!mounted) return;

    // Read the outcome from the board rather than the screen's return value,
    // so backing out of a decided match still records what happened.
    if (!controller.isGameOver) {
      setState(() {}); // still resumable; nothing banked
      return;
    }
    await _bank(controller);
  }

  Future<void> _bank(DuelController controller) async {
    final won = controller.playerWon;
    final health = controller.me.health.clamp(0, 999);
    final turns = controller.state.turnNumber;

    final earned =
        GauntletScoring.score(won: won, healthLeft: health, turns: turns);
    final streak = await save.finishGauntlet(
      dayId: _day.id,
      won: won,
      healthLeft: health,
      turns: turns,
      gold: earned.gold,
      shards: earned.shards,
    );
    // The milestone is known only after the streak advances, so it is paid
    // as a second, smaller settlement rather than folded into the first.
    final milestone = GauntletScoring.streakBonus(streak);
    if (milestone.gold > 0 || milestone.shards > 0) {
      await save.grantCurrency(
          gold: milestone.gold, shards: milestone.shards);
    }
    await save.trackQuest(won ? 'duel_win' : 'battle_loss');
    if (!mounted) return;

    AudioManager.instance.reward();
    Haptics.blow();
    setState(() {
      _streakAfter = streak;
      _justEarned = GauntletReward(
        gold: earned.gold + milestone.gold,
        shards: earned.shards + milestone.shards,
        xp: earned.xp,
        lines: [...earned.lines, ...milestone.lines],
      );
    });
  }

  // ── screen ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      appBar: AppBar(
        title: const Text('DAILY GAUNTLET'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _todayCard(),
          const SizedBox(height: 14),
          if (_justEarned != null) ...[
            _rewardCard(_justEarned!),
            const SizedBox(height: 14),
          ] else if (_done) ...[
            _alreadyPlayedCard(),
            const SizedBox(height: 14),
          ],
          _howItWorks(),
          const SizedBox(height: 14),
          _deckPreview(),
          const SizedBox(height: 18),
          if (!_done) _startButton(),
        ],
      ),
    );
  }

  Widget _todayCard() {
    final colours = _day.dominions
        .map((d) => d.name[0].toUpperCase() + d.name.substring(1))
        .join(' / ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF8FE3FF).withValues(alpha: 0.16),
          Colors.black.withValues(alpha: 0.25),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x558FE3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_day.id,
                  style: const TextStyle(
                      color: Color(0xFF8FE3FF),
                      fontSize: 15,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(_timeLeft,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_day.shape,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _line('Your deck', '$colours — lent to you'),
          _line('Your Health', '${_day.playerHealth}'),
          _line('Opponent',
              '${_day.foeDominion.name[0].toUpperCase()}'
              '${_day.foeDominion.name.substring(1)}'
              ' · ${_tierWord(_day.foeTier)}'),
          _line('Their Health', '${_day.foeHealth}'),
          if (_day.foeBoard.isNotEmpty)
            _line('They open with',
                '${_day.foeBoard.length} unit'
                    '${_day.foeBoard.length == 1 ? '' : 's'} in play'),
          if (save.gauntletStreak > 0) ...[
            const SizedBox(height: 6),
            _line('Your streak', '${save.gauntletStreak} days 🔥'),
          ],
        ],
      ),
    );
  }

  String _tierWord(AiTier tier) => switch (tier) {
        AiTier.greedy => 'aggressive',
        AiTier.tactician => 'measured',
        AiTier.strategist => 'calculating',
      };

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// The rules, stated before the button that commits to them.
  ///
  /// A player who loses their one attempt to a rule nobody told them has been
  /// cheated, and they are right to feel it. This panel is not optional
  /// decoration — it is the thing that makes "one attempt" fair.
  Widget _howItWorks() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HOW IT WORKS',
                style: TextStyle(
                    color: Color(0xFFC9A86A),
                    fontSize: 12,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _rule(Icons.today, 'One attempt a day',
                'Once you start, that is today\'s attempt. If you are '
                    'interrupted you can carry on where you left off — but you '
                    'cannot start the fight over.'),
            _rule(Icons.groups, 'The same fight for everyone',
                'Every player today gets this deck, this opponent, and the '
                    'same order of cards. Only the choices differ.'),
            _rule(Icons.style, 'The deck is lent to you',
                'Your collection does not matter here. Cards you do not own '
                    'are yours for this fight.'),
            _rule(Icons.emoji_events, 'What it pays',
                'Finishing pays ${GauntletScoring.completionGold} Gold, win or '
                    'lose. Winning adds ${GauntletScoring.winGold} Gold and '
                    '${GauntletScoring.winShards} Shards. Finish with '
                    '${GauntletScoring.cleanHealth} Health or more, or inside '
                    '${GauntletScoring.swiftTurns} turns, and each pays more '
                    'again.'),
            _rule(Icons.local_fire_department, 'The streak is the prize',
                'Play on consecutive days and it climbs. Milestones at 3, 7, '
                    '14 and 30. Miss a day and it goes back to one.'),
          ],
        ),
      );

  Widget _rule(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFC9A86A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

  /// The loan deck, so the player can plan before spending the attempt.
  Widget _deckPreview() {
    final counts = <String, int>{};
    _day.deck.forEach((id, n) {
      final def = widget.library.card(id);
      if (def.type == CardType.wellspring) return;
      counts[id] = n;
    });
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final ca = widget.library.card(a).totalCost;
        final cb = widget.library.card(b).totalCost;
        return ca != cb
            ? ca.compareTo(cb)
            : widget.library.card(a).name.compareTo(widget.library.card(b).name);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('TODAY\'S DECK',
                style: TextStyle(
                    color: Color(0xFFC9A86A),
                    fontSize: 12,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('${DailyGauntlet.wellspringCount} Wellsprings included',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final def = widget.library.card(ids[i]);
              return GestureDetector(
                onTap: () => showCardZoom(context, def),
                child: Stack(
                  children: [
                    CardWidget(def: def, width: 88),
                    if (counts[ids[i]]! > 1)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('x${counts[ids[i]]}',
                              style: const TextStyle(
                                  color: Color(0xFFC9A86A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text('Tap a card to read it.',
            style: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }

  Widget _startButton() => Semantics(
        button: true,
        label: _resumable
            ? 'Continue today\'s attempt'
            : 'Begin today\'s attempt',
        child: GestureDetector(
          onTap: _play,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8FE3FF), Color(0xFF3E7FA0)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(_resumable ? 'CONTINUE' : 'BEGIN — ONE ATTEMPT',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF06171F),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
        ),
      );

  Widget _alreadyPlayedCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(save.gauntletWon ? 'You took today.' : 'Today beat you.',
                style: TextStyle(
                    color: save.gauntletWon
                        ? const Color(0xFF7FE0A8)
                        : AppTheme.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              save.gauntletWon
                  ? 'Finished with ${save.gauntletHealthLeft} Health in '
                      '${save.gauntletTurns} turns. $_timeLeft.'
                  : 'The attempt is spent. $_timeLeft.',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );

  Widget _rewardCard(GauntletReward reward) {
    final next = GauntletScoring.nextMilestone(_streakAfter);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A86A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x88C9A86A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('+${reward.gold} GOLD'
              '${reward.shards > 0 ? '   +${reward.shards} SHARDS' : ''}',
              style: const TextStyle(
                  color: Color(0xFFC9A86A),
                  fontSize: 17,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final line in reward.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $line',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      height: 1.4)),
            ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? '$_streakAfter-day streak 🔥'
                : '$_streakAfter-day streak 🔥 — '
                    '${next - _streakAfter} more to the next reward',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
