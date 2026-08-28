/// What one attempt paid out.
class GauntletReward {
  final int gold;
  final int shards;
  final int xp;

  /// The lines shown on the result screen, in the order they were earned.
  final List<String> lines;

  const GauntletReward({
    required this.gold,
    required this.shards,
    required this.xp,
    required this.lines,
  });

  static const none = GauntletReward(gold: 0, shards: 0, xp: 0, lines: []);
}

/// How an attempt is scored and paid.
///
/// Paid the moment the match ends, not the next day. A daily challenge that
/// makes you come back tomorrow to collect is asking for two visits to settle
/// one attempt, and the second visit has nothing to play.
///
/// There are deliberately no rank prizes. Every player gets the identical
/// board, so an optimal line can be written down once and copied by anyone —
/// the bigger the prize for finishing first, the more the leaderboard belongs
/// to whoever copied fastest. These thresholds give the same "I played well"
/// feeling, pay instantly, and cannot be farmed by reading someone else's
/// answer any more than playing well can.
class GauntletScoring {
  GauntletScoring._();

  /// Turning up and finishing, win or lose.
  static const completionGold = 40;
  static const completionXp = 15;

  static const winGold = 80;
  static const winShards = 20;
  static const winXp = 10;

  /// Won without being ground down.
  static const cleanHealth = 15;
  static const cleanGold = 40;
  static const cleanShards = 10;

  /// Won quickly.
  static const swiftTurns = 8;
  static const swiftGold = 40;
  static const swiftShards = 10;

  static GauntletReward score({
    required bool won,
    required int healthLeft,
    required int turns,
  }) {
    var gold = completionGold;
    var shards = 0;
    var xp = completionXp;
    final lines = <String>['Attempt completed  +$completionGold Gold'];

    if (won) {
      gold += winGold;
      shards += winShards;
      xp += winXp;
      lines.add('Victory  +$winGold Gold, +$winShards Shards');

      if (healthLeft >= cleanHealth) {
        gold += cleanGold;
        shards += cleanShards;
        lines.add('Barely scratched — $healthLeft Health left  '
            '+$cleanGold Gold, +$cleanShards Shards');
      }
      if (turns <= swiftTurns) {
        gold += swiftGold;
        shards += swiftShards;
        lines.add('Over in $turns turns  '
            '+$swiftGold Gold, +$swiftShards Shards');
      }
    } else {
      // A single attempt that can pay nothing teaches players to skip the
      // days that look hard, and those are the interesting ones.
      lines.add('No victory today — the deck was still yours to learn.');
    }

    return GauntletReward(gold: gold, shards: shards, xp: xp, lines: lines);
  }

  /// Paid on top when a streak reaches a milestone.
  ///
  /// The streak is what actually brings people back: nobody protects 40 Gold,
  /// but they will protect a 12 that resets to 1.
  ///
  /// Day 14 pays currency rather than the "pick a rare card" that was
  /// discussed — a card picker is a screen of its own and is not built.
  static GauntletReward streakBonus(int streak) {
    switch (streak) {
      case 3:
        return const GauntletReward(
            gold: 100,
            shards: 0,
            xp: 0,
            lines: ['3-day streak — a booster on the house  +100 Gold']);
      case 7:
        return const GauntletReward(
            gold: 200,
            shards: 0,
            xp: 0,
            lines: ['7-day streak  +200 Gold']);
      case 14:
        return const GauntletReward(
            gold: 300,
            shards: 100,
            xp: 0,
            lines: ['14-day streak  +300 Gold, +100 Shards']);
      case 30:
        return const GauntletReward(
            gold: 600,
            shards: 200,
            xp: 0,
            lines: ['30 days without missing one  +600 Gold, +200 Shards']);
      default:
        return GauntletReward.none;
    }
  }

  /// The milestone a player is walking toward, or null past the last one.
  static int? nextMilestone(int streak) {
    for (final m in const [3, 7, 14, 30]) {
      if (streak < m) return m;
    }
    return null;
  }
}
