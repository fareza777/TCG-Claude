import 'package:flutter/material.dart';

import '../services/audio_manager.dart';
import '../services/haptics.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'season.dart';

/// The seasonal track.
///
/// One bar, thirty rungs, and everything the player already does feeds it.
/// The screen's only real job is to make the next reward visible from the
/// first glance — a progression track nobody can see the end of is just a
/// number going up.
class SeasonScreen extends StatefulWidget {
  final SaveService save;

  const SeasonScreen({super.key, required this.save});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  SaveService get save => widget.save;

  Future<void> _claimAll() async {
    final result = await save.claimAllSeasonTiers();
    if (!mounted || result.tiers == 0) return;
    AudioManager.instance.reward();
    Haptics.blow();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Collected ${result.tiers} '
          'reward${result.tiers == 1 ? '' : 's'}: '
          '${result.gold} Gold and ${result.shards} Shards.'),
    ));
    setState(() {});
  }

  String get _endsIn {
    final ends = Season.endOf(save.seasonId.isEmpty
        ? Season.idFor(DateTime.now())
        : save.seasonId);
    final days = ends.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Ends today';
    return 'Ends in $days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final tier = save.seasonTier;
    final owed = save.claimableTiers;
    final complete = tier >= Season.tierCount;

    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      appBar: AppBar(
        title: const Text('SEASON'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          _summary(tier, complete),
          if (owed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  label: 'Collect ${owed.length} season rewards',
                  child: FilledButton.icon(
                    onPressed: _claimAll,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: Text('COLLECT ${owed.length} REWARD'
                        '${owed.length == 1 ? '' : 'S'}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A86A),
                      foregroundColor: const Color(0xFF1C1508),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: _track(tier)),
        ],
      ),
    );
  }

  Widget _summary(int tier, bool complete) {
    final progress = Season.progressInTier(save.seasonXp);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFC9A86A).withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.25),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55C9A86A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TIER $tier',
                  style: const TextStyle(
                      color: Color(0xFFC9A86A),
                      fontSize: 22,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(_endsIn,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: complete
                ? 'Season track complete'
                : 'Tier $tier of ${Season.tierCount}, '
                    '${(progress * 100).round()} percent to the next',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFC9A86A)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Track complete. Nothing left to earn this season.'
                : '${save.seasonXp} XP  ·  '
                    '${Season.xpPerTier - (save.seasonXp % Season.xpPerTier)} '
                    'to the next tier',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every duel, story battle, PvP win and booster feeds this. '
            'Unclaimed rewards are lost when the season ends.',
            style:
                TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _track(int tier) {
    final tiers = Season.tiers;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: tiers.length,
      itemBuilder: (_, i) {
        final t = tiers[i];
        final reached = t.tier <= tier;
        final claimed = save.seasonClaimed.contains(t.tier);
        final accent =
            t.milestone ? const Color(0xFF8FE3FF) : const Color(0xFFC9A86A);

        return Semantics(
          label: 'Tier ${t.tier}, ${t.rewardLabel}, '
              '${claimed ? 'collected' : reached ? 'ready to collect' : 'locked'}',
          child: Opacity(
            opacity: reached ? 1 : 0.45,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: claimed
                    ? Colors.transparent
                    : reached
                        ? accent.withValues(alpha: 0.13)
                        : Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: reached
                      ? accent.withValues(alpha: claimed ? 0.25 : 0.6)
                      : AppTheme.panelBorder,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text('${t.tier}',
                        style: TextStyle(
                            color: reached ? accent : AppTheme.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                  ),
                  if (t.milestone) ...[
                    const Icon(Icons.workspace_premium,
                        size: 16, color: Color(0xFF8FE3FF)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(t.rewardLabel,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13)),
                  ),
                  if (claimed)
                    const Icon(Icons.check,
                        size: 17, color: Color(0xFF7FE0A8))
                  else if (reached)
                    Text('READY',
                        style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900))
                  else
                    Text('${t.xpRequired} XP',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
