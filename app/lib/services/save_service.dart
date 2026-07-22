import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// Persistent player profile: gold, card ownership, story progress, decks.
///
/// Economy (v0.5):
///   start          : 120 gold + the Verdance starter cards
///   duel win       : +25 gold
///   story battle   : +150 gold on first clear, +20 on replays
///   chapter clear  : +250 gold bonus (first time)
///   Shard Pack     : 100 gold
class SaveService extends ChangeNotifier {
  static const startGold = 120;
  static const duelWinGold = 25;
  static const storyFirstClearGold = 150;
  static const storyReplayGold = 20;
  static const chapterClearGold = 250;
  static const packCost = 100;

  final SharedPreferences _prefs;
  int gold;
  int shards;
  Map<String, int> owned; // cardId -> copies
  Map<String, int> chapterStage; // chapterId -> highest reached stage
  Set<String> chaptersDone;
  Set<String> clearedBattles; // "ch1:2"
  Map<String, List<String>> decks; // deckName -> [cardId,...] (with repeats)
  List<Map<String, dynamic>> quests; // daily quests
  String questDate; // yyyy-mm-dd the quests were rolled
  bool tutorialSeen;
  bool musicOn;
  bool sfxOn;
  bool colorblind;
  bool reduceMotion;

  // Progression (#6): daily login streak + lifetime stats + achievements.
  int loginStreak = 0;
  String lastLoginDate = '';
  int totalWins = 0;
  int totalPacks = 0;
  Set<String> achievements = {};

  /// Set once on load when a new day's login bonus is granted (gold amount);
  /// the menu shows it, then calls [clearPendingDailyBonus].
  int pendingDailyBonus = 0;

  /// Achievement ids unlocked this session (for a one-time toast).
  final List<String> pendingAchievements = [];

  // Crafting economy (Shards).
  static const craftCost = {
    Rarity.common: 20,
    Rarity.uncommon: 60,
    Rarity.rare: 200,
    Rarity.epic: 600,
    Rarity.legendary: 1800,
  };
  static const disenchantValue = {
    Rarity.common: 5,
    Rarity.uncommon: 15,
    Rarity.rare: 50,
    Rarity.epic: 150,
    Rarity.legendary: 450,
  };
  int maxCopies(Rarity r) => r == Rarity.legendary ? 1 : 3;

  SaveService._(
    this._prefs, {
    required this.gold,
    required this.shards,
    required this.owned,
    required this.chapterStage,
    required this.chaptersDone,
    required this.clearedBattles,
    required this.decks,
    required this.quests,
    required this.questDate,
    required this.tutorialSeen,
    required this.musicOn,
    required this.sfxOn,
    required this.colorblind,
    required this.reduceMotion,
  });

  static Future<SaveService> load(CardLibrary library) async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = !prefs.containsKey('gold');

    Map<String, int> intMap(String key) {
      final s = prefs.getString(key);
      if (s == null) return {};
      return (json.decode(s) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    }

    Map<String, List<String>> deckMap() {
      final s = prefs.getString('decks');
      if (s == null) return {};
      return (json.decode(s) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, [for (final id in v as List) id as String]));
    }

    List<Map<String, dynamic>> questList() {
      final s = prefs.getString('quests');
      if (s == null) return [];
      return [
        for (final q in json.decode(s) as List)
          Map<String, dynamic>.from(q as Map),
      ];
    }

    final service = SaveService._(
      prefs,
      gold: prefs.getInt('gold') ?? startGold,
      shards: prefs.getInt('shards') ?? 0,
      owned: intMap('owned'),
      chapterStage: intMap('chapterStage'),
      chaptersDone: (prefs.getStringList('chaptersDone') ?? const []).toSet(),
      clearedBattles:
          (prefs.getStringList('clearedBattles') ?? const []).toSet(),
      decks: deckMap(),
      quests: questList(),
      questDate: prefs.getString('questDate') ?? '',
      tutorialSeen: prefs.getBool('tutorialSeen') ?? false,
      musicOn: prefs.getBool('musicOn') ?? true,
      sfxOn: prefs.getBool('sfxOn') ?? true,
      colorblind: prefs.getBool('colorblind') ?? false,
      reduceMotion: prefs.getBool('reduceMotion') ?? false,
    );
    service.loginStreak = prefs.getInt('loginStreak') ?? 0;
    service.lastLoginDate = prefs.getString('lastLoginDate') ?? '';
    service.totalWins = prefs.getInt('totalWins') ?? 0;
    service.totalPacks = prefs.getInt('totalPacks') ?? 0;
    service.achievements =
        (prefs.getStringList('achievements') ?? const []).toSet();
    service._rollDailyQuestsIfNeeded();
    service._checkLogin();

    if (firstLaunch) {
      final starter = library.starterDecks['VERDANCE'];
      if (starter != null) {
        for (final id in starter.cardIds) {
          service.owned[id] = 3;
        }
        service.owned[starter.wellspringId] = 16;
      }
      await service._persist();
    }
    return service;
  }

  int copiesOf(String cardId) => owned[cardId] ?? 0;
  int get uniqueOwned => owned.keys.length;
  bool get canBuyPack => gold >= packCost;

  int stageOf(String chapterId) => chapterStage[chapterId] ?? 0;
  bool chapterDone(String chapterId) => chaptersDone.contains(chapterId);

  Future<void> addGold(int amount) async {
    gold += amount;
    await _persist();
    notifyListeners();
  }

  Future<bool> buyPack(List<CardDef> cards) async {
    if (!canBuyPack) return false;
    gold -= packCost;
    for (final c in cards) {
      final have = owned[c.id] ?? 0;
      if (have >= maxCopies(c.rarity)) {
        // Extra copy beyond the deck limit → converted to Shards.
        shards += disenchantValue[c.rarity]!;
      } else {
        owned[c.id] = have + 1;
      }
    }
    // pack_open quest progress
    for (final q in quests) {
      if (q['event'] == 'pack_open' &&
          (q['progress'] as int) < (q['target'] as int)) {
        q['progress'] = (q['progress'] as int) + 1;
      }
    }
    totalPacks += 1;
    _checkAchievements();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<int> rewardStoryBattle(String battleKey) async {
    final first = !clearedBattles.contains(battleKey);
    clearedBattles.add(battleKey);
    final amount = first ? storyFirstClearGold : storyReplayGold;
    gold += amount;
    await _persist();
    notifyListeners();
    return amount;
  }

  Future<void> setChapterStage(String chapterId, int stage) async {
    if (stage > (chapterStage[chapterId] ?? 0)) {
      chapterStage[chapterId] = stage;
      await _persist();
      notifyListeners();
    }
  }

  /// Returns the chapter-clear bonus (0 if already cleared before).
  Future<int> completeChapter(String chapterId) async {
    if (chaptersDone.contains(chapterId)) return 0;
    chaptersDone.add(chapterId);
    gold += chapterClearGold;
    _checkAchievements();
    await _persist();
    notifyListeners();
    return chapterClearGold;
  }

  Future<void> saveDeck(String name, List<String> cardIds) async {
    decks[name] = cardIds;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteDeck(String name) async {
    decks.remove(name);
    await _persist();
    notifyListeners();
  }

  Future<void> markTutorialSeen() async {
    tutorialSeen = true;
    await _persist();
  }

  Future<void> setAudio({bool? music, bool? sfx}) async {
    if (music != null) musicOn = music;
    if (sfx != null) sfxOn = sfx;
    await _persist();
    notifyListeners();
  }

  Future<void> setColorblind(bool on) async {
    colorblind = on;
    await _persist();
    notifyListeners();
  }

  Future<void> setReduceMotion(bool on) async {
    reduceMotion = on;
    await _persist();
    notifyListeners();
  }

  // ── save export / import (local backup; cloud sync is future work) ────
  String exportCode() {
    final data = {
      'gold': gold,
      'shards': shards,
      'owned': owned,
      'chapterStage': chapterStage,
      'chaptersDone': chaptersDone.toList(),
      'clearedBattles': clearedBattles.toList(),
      'decks': decks,
      'tutorialSeen': tutorialSeen,
      'totalWins': totalWins,
      'totalPacks': totalPacks,
      'achievements': achievements.toList(),
      'loginStreak': loginStreak,
    };
    return 'SFSAVE-${base64Url.encode(utf8.encode(json.encode(data)))}';
  }

  Future<bool> importCode(String code) async {
    try {
      final raw = code.trim().replaceFirst('SFSAVE-', '');
      final data =
          json.decode(utf8.decode(base64Url.decode(raw))) as Map<String, dynamic>;
      gold = data['gold'] as int? ?? gold;
      shards = data['shards'] as int? ?? shards;
      owned = (data['owned'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int));
      chapterStage = (data['chapterStage'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int));
      chaptersDone =
          (data['chaptersDone'] as List? ?? const []).cast<String>().toSet();
      clearedBattles =
          (data['clearedBattles'] as List? ?? const []).cast<String>().toSet();
      decks = (data['decks'] as Map<String, dynamic>? ?? {}).map((k, v) =>
          MapEntry(k, [for (final id in v as List) id as String]));
      tutorialSeen = data['tutorialSeen'] as bool? ?? tutorialSeen;
      totalWins = data['totalWins'] as int? ?? totalWins;
      totalPacks = data['totalPacks'] as int? ?? totalPacks;
      achievements =
          (data['achievements'] as List? ?? const []).cast<String>().toSet();
      loginStreak = data['loginStreak'] as int? ?? loginStreak;
      await _persist();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── crafting ────────────────────────────────────────────────────────
  bool canCraft(CardDef def) =>
      shards >= craftCost[def.rarity]! &&
      copiesOf(def.id) < maxCopies(def.rarity);

  Future<bool> craftCard(CardDef def) async {
    if (!canCraft(def)) return false;
    shards -= craftCost[def.rarity]!;
    owned[def.id] = (owned[def.id] ?? 0) + 1;
    await _persist();
    notifyListeners();
    return true;
  }

  bool canDisenchant(CardDef def) => copiesOf(def.id) > 0;

  Future<int> disenchantCard(CardDef def) async {
    if (!canDisenchant(def)) return 0;
    final v = disenchantValue[def.rarity]!;
    owned[def.id] = owned[def.id]! - 1;
    if (owned[def.id]! <= 0) owned.remove(def.id);
    shards += v;
    await _persist();
    notifyListeners();
    return v;
  }

  // ── daily quests ────────────────────────────────────────────────────
  static const _questPool = [
    {'desc': 'Win 2 battles', 'event': 'battle_win', 'target': 2, 'gold': 60, 'shards': 0},
    {'desc': 'Win 3 battles', 'event': 'battle_win', 'target': 3, 'gold': 90, 'shards': 20},
    {'desc': 'Win a story battle', 'event': 'story_win', 'target': 1, 'gold': 80, 'shards': 0},
    {'desc': 'Open a Shard Pack', 'event': 'pack_open', 'target': 1, 'gold': 40, 'shards': 30},
    {'desc': 'Win a duel', 'event': 'duel_win', 'target': 1, 'gold': 40, 'shards': 0},
  ];

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _rollDailyQuestsIfNeeded() {
    final today = _today();
    if (questDate == today && quests.isNotEmpty) return;
    questDate = today;
    // Pick 3 distinct quests deterministically from the day.
    final seed = today.hashCode;
    final pool = List<Map<String, Object>>.from(_questPool);
    final picked = <Map<String, dynamic>>[];
    var s = seed;
    while (picked.length < 3 && pool.isNotEmpty) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final q = pool.removeAt(s % pool.length);
      picked.add({
        'desc': q['desc'],
        'event': q['event'],
        'target': q['target'],
        'gold': q['gold'],
        'shards': q['shards'],
        'progress': 0,
        'claimed': false,
      });
    }
    quests = picked;
  }

  /// Advance quest progress for an event. [event] is one of the quest event
  /// keys; 'duel_win' and 'story_win' also count as 'battle_win'.
  Future<void> trackQuest(String event) async {
    final events = {event, if (event.endsWith('_win')) 'battle_win'};
    var changed = false;
    for (final q in quests) {
      if (events.contains(q['event']) &&
          (q['progress'] as int) < (q['target'] as int)) {
        q['progress'] = (q['progress'] as int) + 1;
        changed = true;
      }
    }
    // Lifetime win stat drives achievements.
    if (event.endsWith('_win')) {
      totalWins += 1;
      _checkAchievements();
      changed = true;
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  bool questComplete(Map<String, dynamic> q) =>
      (q['progress'] as int) >= (q['target'] as int);
  bool questClaimable(Map<String, dynamic> q) =>
      questComplete(q) && q['claimed'] != true;

  Future<void> claimQuest(int index) async {
    final q = quests[index];
    if (!questClaimable(q)) return;
    q['claimed'] = true;
    gold += q['gold'] as int;
    shards += q['shards'] as int;
    await _persist();
    notifyListeners();
  }

  int get claimableQuests =>
      quests.where(questClaimable).length;

  // ── progression: login streak + achievements (#6) ─────────────────────

  /// Yesterday's date string, for streak continuity.
  static String _yesterday() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Update the login streak once per calendar day and grant a scaling bonus.
  void _checkLogin() {
    final today = _today();
    if (lastLoginDate == today) return; // already counted today
    if (lastLoginDate == _yesterday()) {
      loginStreak += 1;
    } else {
      loginStreak = 1; // reset (missed a day, or first ever)
    }
    lastLoginDate = today;
    final bonus = (20 + (loginStreak - 1) * 10).clamp(20, 100);
    gold += bonus;
    pendingDailyBonus = bonus;
    // Persist synchronously-ish; load() awaits nothing after this but the
    // firstLaunch branch persists, and normal flow persists on first action.
    _prefs.setInt('loginStreak', loginStreak);
    _prefs.setString('lastLoginDate', lastLoginDate);
    _prefs.setInt('gold', gold);
  }

  void clearPendingDailyBonus() => pendingDailyBonus = 0;

  /// Achievement catalogue: id → (title, description, one-time reward gold).
  static const achievementCatalogue = <String, (String, String, int)>{
    'first_blood': ('First Blood', 'Win your first battle', 50),
    'veteran': ('Veteran', 'Win 25 battles', 300),
    'warlord': ('Warlord', 'Win 100 battles', 1000),
    'collector_50': ('Collector', 'Own 50 different cards', 150),
    'collector_100': ('Archivist', 'Own 100 different cards', 400),
    'full_set': ('Completionist', 'Own all 190 cards', 2000),
    'chapter_one': ('The Waking Grove', 'Clear Chapter I', 100),
    'saga_done': ('Loneliest War', 'Clear all 5 chapters of Set 1', 1500),
    'pack_rat': ('Pack Rat', 'Open 10 Shard Packs', 200),
  };

  bool hasAchievement(String id) => achievements.contains(id);

  /// Re-evaluate achievements against current stats; unlock + reward any newly
  /// earned ones. Safe to call after any progress event.
  void _checkAchievements() {
    void unlock(String id, bool earned) {
      if (earned && !achievements.contains(id)) {
        achievements.add(id);
        gold += achievementCatalogue[id]!.$3;
        pendingAchievements.add(id);
      }
    }

    unlock('first_blood', totalWins >= 1);
    unlock('veteran', totalWins >= 25);
    unlock('warlord', totalWins >= 100);
    unlock('collector_50', uniqueOwned >= 50);
    unlock('collector_100', uniqueOwned >= 100);
    unlock('full_set', uniqueOwned >= 190);
    unlock('chapter_one', chaptersDone.contains('ch1'));
    unlock('saga_done', chaptersDone.length >= 5);
    unlock('pack_rat', totalPacks >= 10);
  }

  Future<void> _persist() async {
    await _prefs.setInt('gold', gold);
    await _prefs.setInt('shards', shards);
    await _prefs.setString('quests', json.encode(quests));
    await _prefs.setString('questDate', questDate);
    await _prefs.setString('owned', json.encode(owned));
    await _prefs.setString('chapterStage', json.encode(chapterStage));
    await _prefs.setStringList('chaptersDone', chaptersDone.toList());
    await _prefs.setStringList('clearedBattles', clearedBattles.toList());
    await _prefs.setString('decks', json.encode(decks));
    await _prefs.setBool('tutorialSeen', tutorialSeen);
    await _prefs.setBool('musicOn', musicOn);
    await _prefs.setBool('sfxOn', sfxOn);
    await _prefs.setBool('colorblind', colorblind);
    await _prefs.setBool('reduceMotion', reduceMotion);
    await _prefs.setInt('loginStreak', loginStreak);
    await _prefs.setString('lastLoginDate', lastLoginDate);
    await _prefs.setInt('totalWins', totalWins);
    await _prefs.setInt('totalPacks', totalPacks);
    await _prefs.setStringList('achievements', achievements.toList());
  }
}
