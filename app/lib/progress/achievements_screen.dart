import 'package:flutter/material.dart';

import '../services/save_service.dart';
import '../theme.dart';

/// Lifetime progression: login streak, stats, and the achievement catalogue.
class AchievementsScreen extends StatelessWidget {
  final SaveService save;
  const AchievementsScreen({super.key, required this.save});

  @override
  Widget build(BuildContext context) {
    final entries = SaveService.achievementCatalogue.entries.toList();
    final unlocked = entries.where((e) => save.hasAchievement(e.key)).length;

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
                    const Text('Achievements',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('$unlocked/${entries.length}',
                        style: const TextStyle(
                            color: Color(0xFFE3B341),
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              _statsRow(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final (title, desc, reward) = e.value;
                    final done = save.hasAchievement(e.key);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: done ? 0.4 : 0.22),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: done
                                ? const Color(0xFFE3B341).withValues(alpha: 0.7)
                                : AppTheme.panelBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(done ? Icons.emoji_events : Icons.lock_outline,
                              color: done
                                  ? const Color(0xFFE3B341)
                                  : AppTheme.textMuted,
                              size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TextStyle(
                                        color: done
                                            ? AppTheme.textPrimary
                                            : AppTheme.textMuted,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                Text(desc,
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11.5)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on,
                                  size: 13, color: Color(0xFFE3B341)),
                              const SizedBox(width: 3),
                              Text('$reward',
                                  style: const TextStyle(
                                      color: Color(0xFFF0E4C0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFB48AD1).withValues(alpha: 0.16),
          Colors.black.withValues(alpha: 0.2),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.panelBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('🔥', '${save.loginStreak}', 'day streak'),
          _stat('⚔', '${save.totalWins}', 'wins'),
          _stat('📦', '${save.totalPacks}', 'packs'),
          _stat('🎴', '${save.uniqueOwned}', 'cards'),
        ],
      ),
    );
  }

  Widget _stat(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}
