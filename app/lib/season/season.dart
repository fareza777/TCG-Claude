/// One rung of the seasonal track.
class SeasonTier {
  final int tier;

  /// Total XP needed to have reached this tier.
  final int xpRequired;

  final int gold;
  final int shards;

  /// Milestone rungs pay enough Gold for a pack outright and are drawn
  /// differently, so there is always a visible next thing worth walking to.
  final bool milestone;

  const SeasonTier(this.tier, this.xpRequired,
      {this.gold = 0, this.shards = 0, this.milestone = false});

  String get rewardLabel => [
        if (gold > 0) '$gold Gold',
        if (shards > 0) '$shards Shards',
      ].join(' + ');
}

/// A month-long free progression track.
///
/// The game already had Gold, Shards, daily quests, a login streak, arena and
/// a ladder — every ingredient of a reason to come back, and nothing tying
/// them together. This is the thread: everything you already do feeds one
/// visible bar, and the bar pays out.
///
/// Free only, on purpose. A paid tier is a real option later, but shipping the
/// track first means the decision can be made against something players are
/// actually using rather than a guess.
class Season {
  Season._();

  /// XP per event, keyed to the events `trackQuest` actually emits.
  ///
  /// Only these three: arena wins already arrive as `duel_win`, and opening a
  /// pack is handled inside `buyPack` rather than through the quest hook. A
  /// key here that nothing ever sends would be a reward nobody can earn.
  static const xpFor = <String, int>{
    'duel_win': 10,
    'story_win': 15,
    'pvp_win': 20,
  };

  /// Opening a booster. Granted directly by the save file, which is where
  /// packs are bought.
  static const xpPerPack = 5;

  /// Deliberately reachable: a track most players cannot complete is a track
  /// most players ignore.
  ///
  /// 30 x 50 = 1500 XP for the full track. A player who wins three duels,
  /// clears two story battles and opens a pack on a given day earns 65, so the
  /// month closes with room to miss a week. This was first written at 100 per
  /// tier, which needed 3000 and quietly made the track uncompletable — the
  /// season test now holds the arithmetic to the claim.
  static const xpPerTier = 50;
  static const tierCount = 30;

  /// Gold that buys exactly one booster, paid at every fifth rung.
  static const _milestoneGold = 100;

  /// The reward at each rung.
  ///
  /// Paid in Gold and Shards because those are the currencies the save file
  /// already keeps. Inventing a pack inventory to hand out packs would have
  /// been a second way to own the same thing, and Gold buys a pack anyway.
  static List<SeasonTier> get tiers => [
        for (var t = 1; t <= tierCount; t++)
          if (t % 5 == 0)
            SeasonTier(t, t * xpPerTier,
                gold: _milestoneGold, shards: 40, milestone: true)
          else
            SeasonTier(t, t * xpPerTier,
                gold: t.isEven ? 60 : 40, shards: t % 3 == 0 ? 25 : 0),
      ];

  /// The season a date belongs to, as `YYYY-MM`.
  ///
  /// Derived from the calendar rather than stored, so a player who does not
  /// open the game for six weeks still lands in the right season, and no
  /// server has to tell the client what month it is.
  static String idFor(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}';

  /// Midnight on the first of the following month, in local time.
  static DateTime endOf(String seasonId) {
    final parts = seasonId.split('-');
    final year = int.tryParse(parts.first) ?? DateTime.now().year;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
  }

  /// How many complete tiers [xp] has earned.
  static int tierFor(int xp) =>
      (xp ~/ xpPerTier).clamp(0, tierCount);

  /// Progress through the current tier, 0.0–1.0. Full once the track is done.
  static double progressInTier(int xp) {
    if (tierFor(xp) >= tierCount) return 1;
    return (xp % xpPerTier) / xpPerTier;
  }
}
