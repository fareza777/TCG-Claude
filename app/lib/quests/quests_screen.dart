import 'package:flutter/material.dart';

import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';

/// Daily quests — progress, claim rewards. Refreshes each day.
class QuestsScreen extends StatelessWidget {
  final SaveService save;

  const QuestsScreen({super.key, required this.save});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('Daily Quests',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('New quests every day. Complete them for gold and Shards.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: save,
                  builder: (context, _) => ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: save.quests.length,
                    itemBuilder: (context, i) => _questCard(context, i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questCard(BuildContext context, int i) {
    final q = save.quests[i];
    final progress = q['progress'] as int;
    final target = q['target'] as int;
    final done = save.questComplete(q);
    final claimable = save.questClaimable(q);
    final claimed = q['claimed'] == true;
    final gold = q['gold'] as int;
    final shards = q['shards'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: claimable
                ? const Color(0xFFE3B341)
                : AppTheme.panelBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            claimed
                ? Icons.check_circle
                : done
                    ? Icons.emoji_events
                    : Icons.flag_outlined,
            color: claimed
                ? const Color(0xFF7FE0A8)
                : done
                    ? const Color(0xFFE3B341)
                    : AppTheme.textMuted,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['desc'] as String,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / target).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.black38,
                    valueColor: AlwaysStoppedAnimation(
                        done ? const Color(0xFF7FE0A8) : const Color(0xFF6FB0DC)),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text('$progress / $target',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                    const Spacer(),
                    const Icon(Icons.monetization_on,
                        color: Color(0xFFE3B341), size: 12),
                    Text(' $gold',
                        style: const TextStyle(
                            color: Color(0xFFF0E4C0), fontSize: 11)),
                    if (shards > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.hexagon,
                          color: Color(0xFF8FE3FF), size: 11),
                      Text(' $shards',
                          style: const TextStyle(
                              color: Color(0xFFCFEFFF), fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimable)
            GestureDetector(
              onTap: () {
                AudioManager.instance.reward();
                save.claimQuest(i);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFC9A86A), Color(0xFF8A713A)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('CLAIM',
                    style: TextStyle(
                        color: Color(0xFF1C1508),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
            )
          else if (claimed)
            const Text('Claimed',
                style: TextStyle(color: Color(0xFF7FE0A8), fontSize: 12)),
        ],
      ),
    );
  }
}
