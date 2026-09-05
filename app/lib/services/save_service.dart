import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../season/season.dart';

import 'purchase_catalog.dart';

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

  /// Gold paid for watching a rewarded video, and how many a day count.
  /// Sized to be worth the interruption the player chose — two watches buy a
  /// Shard Pack, three cover an arena entry — without making Gold worthless.
  static const adGoldReward = 50;
  static const adGoldDailyCap = 3;

  /// Arena entry. Priced so that a run pays for itself on the third win —
  /// good players sustain themselves, everyone else feels the cost.
  static const arenaEntryCost = 150;

  /// Gold paid for the Nth arena win (1-indexed). Cumulative payouts:
  /// 25 · 75 · 150 · 250 · 375 · 525 · 700 · 900 · 1125 · 1375.
  /// Third win exactly refunds the 150 entry; everything past it is profit,
  /// and the curve steepens where the runs get genuinely hard.
  static const arenaWinGold = [25, 50, 75, 100, 125, 150, 175, 200, 225, 250];

  static int arenaGoldForWin(int winNumber) => winNumber <= 0
      ? 0
      : arenaWinGold[(winNumber - 1).clamp(0, arenaWinGold.length - 1)];

  final SharedPreferences _prefs;
  int gold;
  int shards;
  Map<String, int> owned; // cardId -> copies
  Map<String, int> chapterStage; // chapterId -> highest reached stage
  Set<String> chaptersDone;
  Set<String> clearedBattles; // "ch1:2"
  Map<String, List<String>> decks; // deckName -> [cardId,...] (with repeats)
  /// The season these numbers belong to, as `YYYY-MM`. A mismatch on load
  /// means a new month has started and the track resets.
  /// The Gauntlet day the player has an attempt open or finished on, and
  /// what happened. One attempt per day is the whole point of the mode, so
  /// this is what enforces it.
  String gauntletDay = '';
  bool gauntletStarted = false;
  bool gauntletFinished = false;
  bool gauntletWon = false;
  int gauntletHealthLeft = 0;
  int gauntletTurns = 0;

  /// Consecutive days on which an attempt was finished, and the last such day.
  int gauntletStreak = 0;
  String gauntletLastDay = '';

  String seasonId;
  int seasonXp;
  List<int> seasonClaimed; // tiers already collected
  List<Map<String, dynamic>> quests; // daily quests
  String questDate; // yyyy-mm-dd the quests were rolled
  bool tutorialSeen;
  bool musicOn;
  bool sfxOn;
  bool voiceOn;
  bool hapticsOn;
  bool colorblind;
  bool reduceMotion;

  /// The player chose "Play as Guest" on the login screen, so it is not
  /// shown again. Device-local on purpose: this is about who signs in here,
  /// not progress, so it never joins save codes or cloud snapshots.
  bool guestMode = false;

  /// The player has explicitly linked a Google account on this device.
  /// Gates the silent re-auth at startup: without it, launching the game
  /// must not surface a Google prompt out of nowhere.
  bool accountLinked = false;

  // Progression (#6): daily login streak + lifetime stats + achievements.
  int loginStreak = 0;
  String lastLoginDate = '';
  int totalWins = 0;
  int totalPacks = 0;
  Set<String> achievements = {};

  // Arena — best win streak in the Proving Gauntlet.
  int arenaBestWins = 0;

  /// Battles finished, win or lose. Gates the new-player grace period: the
  /// first few fights are never interrupted by an interstitial.
  int battlesPlayed = 0;

  /// Rewarded-video Gold claimed today, and the day it was counted for.
  int adGoldClaims = 0;
  String adGoldDate = '';

  /// Set once on load when a new day's login bonus is granted (gold amount);
  /// the menu shows it, then calls [clearPendingDailyBonus].
  int pendingDailyBonus = 0;

  /// Achievement ids unlocked this session (for a one-time toast).
  final List<String> pendingAchievements = [];

  /// Google Play purchase identifiers already delivered to the local profile.
  final Set<String> processedPurchaseIds = {};

  /// Purchase identifiers whose Gold has been taken back after Google voided
  /// the payment. Kept forever so a refund cannot be re-granted by a restore.
  final Set<String> revokedPurchaseIds = {};

  /// Purchases delivered on this device but not yet recorded by the backend,
  /// kept as "productId|purchaseToken".
  ///
  /// Retried until the backend confirms them, so a payment made while the
  /// backend is unreachable still becomes durable rather than silently
  /// existing only on this device.
  final Set<String> unverifiedPurchases = {};

  /// True while at least one Google-verified Remove Ads purchase is active on
  /// this device. The value is persisted so a completed Play purchase can
  /// suppress ads immediately, even when the backend is temporarily offline.
  bool removeAds = false;

  /// Purchase token/order identifiers that currently support [removeAds].
  /// Keeping every identifier makes restore and refund handling idempotent
  /// when Play and the backend expose different aliases for one purchase.
  final Set<String> removeAdsPurchaseIds = {};

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
    required this.seasonId,
    required this.seasonXp,
    required this.seasonClaimed,
    required this.quests,
    required this.questDate,
    required this.tutorialSeen,
    required this.musicOn,
    required this.sfxOn,
    required this.voiceOn,
    required this.hapticsOn,
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
      seasonId: prefs.getString('seasonId') ?? '',
      seasonXp: prefs.getInt('seasonXp') ?? 0,
      seasonClaimed: (prefs.getStringList('seasonClaimed') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList(),
      quests: questList(),
      questDate: prefs.getString('questDate') ?? '',
      tutorialSeen: prefs.getBool('tutorialSeen') ?? false,
      musicOn: prefs.getBool('musicOn') ?? true,
      sfxOn: prefs.getBool('sfxOn') ?? true,
      voiceOn: prefs.getBool('voiceOn') ?? true,
      hapticsOn: prefs.getBool('hapticsOn') ?? true,
      colorblind: prefs.getBool('colorblind') ?? false,
      reduceMotion: prefs.getBool('reduceMotion') ?? false,
    );
    service.loginStreak = prefs.getInt('loginStreak') ?? 0;
    service.gauntletDay = prefs.getString('gauntletDay') ?? '';
    service.gauntletStarted = prefs.getBool('gauntletStarted') ?? false;
    service.gauntletFinished = prefs.getBool('gauntletFinished') ?? false;
    service.gauntletWon = prefs.getBool('gauntletWon') ?? false;
    service.gauntletHealthLeft = prefs.getInt('gauntletHealthLeft') ?? 0;
    service.gauntletTurns = prefs.getInt('gauntletTurns') ?? 0;
    service.gauntletStreak = prefs.getInt('gauntletStreak') ?? 0;
    service.gauntletLastDay = prefs.getString('gauntletLastDay') ?? '';
    service.lastLoginDate = prefs.getString('lastLoginDate') ?? '';
    service.guestMode = prefs.getBool('guestMode') ?? false;
    service.accountLinked = prefs.getBool('accountLinked') ?? false;
    service.totalWins = prefs.getInt('totalWins') ?? 0;
    service.totalPacks = prefs.getInt('totalPacks') ?? 0;
    service.achievements =
        (prefs.getStringList('achievements') ?? const []).toSet();
    service.processedPurchaseIds
        .addAll(prefs.getStringList('processedPurchaseIds') ?? const []);
    service.unverifiedPurchases
        .addAll(prefs.getStringList('unverifiedPurchases') ?? const []);
    service.revokedPurchaseIds
        .addAll(prefs.getStringList('revokedPurchaseIds') ?? const []);
    service.removeAdsPurchaseIds
        .addAll(prefs.getStringList('removeAdsPurchaseIds') ?? const []);
    service.removeAds = (prefs.getBool('removeAds') ?? false) ||
        service.removeAdsPurchaseIds.isNotEmpty;
    service.arenaBestWins = prefs.getInt('arenaBestWins') ?? 0;
    service.battlesPlayed = prefs.getInt('battlesPlayed') ?? 0;
    service.adGoldClaims = prefs.getInt('adGoldClaims') ?? 0;
    service.adGoldDate = prefs.getString('adGoldDate') ?? '';
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
  bool get canEnterArena => gold >= arenaEntryCost;

  /// Takes the arena entry fee. Returns false — and charges nothing — when the
  /// player cannot afford it, so the caller can never start an unpaid run.
  Future<bool> payArenaEntry() async {
    if (gold < arenaEntryCost) return false;
    gold -= arenaEntryCost;
    await _persist();
    notifyListeners();
    return true;
  }

  int stageOf(String chapterId) => chapterStage[chapterId] ?? 0;
  bool chapterDone(String chapterId) => chaptersDone.contains(chapterId);

  /// Adds both currencies in one write.
  ///
  /// addGold exists and shards had no equivalent, so callers that paid both
  /// were reaching into the field directly. One method, one persist.
  Future<void> grantCurrency({int gold = 0, int shards = 0}) async {
    if (gold == 0 && shards == 0) return;
    this.gold += gold;
    this.shards += shards;
    await _persist();
    notifyListeners();
  }

  Future<void> addGold(int amount) async {
    gold += amount;
    await _persist();
    notifyListeners();
  }

  /// Queues a delivered purchase for backend verification.
  static String unverifiedKey(String productId, String purchaseToken) =>
      '$productId|$purchaseToken';

  Future<void> markPurchaseUnverified(
    String productId,
    String purchaseToken,
  ) async {
    if (purchaseToken.isEmpty) return;
    if (unverifiedPurchases.add(unverifiedKey(productId, purchaseToken))) {
      await _persist();
    }
  }

  Future<void> markPurchaseVerified(
    String productId,
    String purchaseToken,
  ) async {
    if (unverifiedPurchases.remove(unverifiedKey(productId, purchaseToken))) {
      await _persist();
    }
  }

  /// Delivers a paid Gold grant exactly once.
  ///
  /// The same purchase reaches this method under different identifiers: Play
  /// reports an order ID, while the backend ledger is keyed on the purchase
  /// token. Passing every known identifier in [aliasIds] lets one grant be
  /// recognised no matter which one arrives first.
  Future<bool> grantPurchasedGold({
    required String productId,
    required String purchaseId,
    Set<String> aliasIds = const {},
  }) async {
    final ids = {purchaseId, ...aliasIds}
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (productId != PurchaseCatalog.gold500Id || ids.isEmpty) return false;

    // A refunded purchase must never come back through a restore.
    if (ids.any(revokedPurchaseIds.contains)) {
      revokedPurchaseIds.addAll(ids);
      return false;
    }

    if (ids.any(processedPurchaseIds.contains)) {
      // Already delivered under one identifier. Record the rest so a later
      // delivery keyed on a different one still resolves to this same grant.
      final known = processedPurchaseIds.length;
      processedPurchaseIds.addAll(ids);
      if (processedPurchaseIds.length != known) await _persist();
      return false;
    }

    gold += PurchaseCatalog.gold500Amount;
    processedPurchaseIds.addAll(ids);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Takes back the Gold from a purchase Google has voided.
  ///
  /// The balance floors at zero. A player who already spent refunded Gold is
  /// not pushed negative — that would leave the profile unable to function,
  /// and the money side is already settled by Google.
  Future<bool> revokePurchasedGold({
    required String productId,
    required String purchaseId,
    Set<String> aliasIds = const {},
  }) async {
    final ids = {purchaseId, ...aliasIds}
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (productId != PurchaseCatalog.gold500Id || ids.isEmpty) return false;
    if (ids.any(revokedPurchaseIds.contains)) return false;

    final wasDelivered = ids.any(processedPurchaseIds.contains);
    revokedPurchaseIds.addAll(ids);

    if (!wasDelivered) {
      // Refunded on another device before this one ever delivered it. Recording
      // the id is enough to keep a later restore from granting it.
      await _persist();
      return false;
    }

    gold = (gold - PurchaseCatalog.gold500Amount).clamp(0, gold);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Delivers the permanent Remove Ads entitlement exactly once per Play
  /// purchase identifier. A second purchase can be recorded without toggling
  /// the visible state, which keeps cross-device reconciliation idempotent.
  Future<bool> grantRemoveAds({
    required String productId,
    required String purchaseId,
    Set<String> aliasIds = const {},
  }) async {
    final ids = {purchaseId, ...aliasIds}
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (productId != PurchaseCatalog.removeAdsId || ids.isEmpty) return false;

    if (ids.any(revokedPurchaseIds.contains)) {
      final before = revokedPurchaseIds.length;
      revokedPurchaseIds.addAll(ids);
      if (revokedPurchaseIds.length != before) await _persist();
      return false;
    }

    final newIds = ids.difference(removeAdsPurchaseIds);
    if (newIds.isEmpty) return false;

    final wasOwned = removeAds;
    removeAdsPurchaseIds.addAll(newIds);
    removeAds = true;
    await _persist();
    if (!wasOwned) notifyListeners();
    return true;
  }

  /// Revokes only the supplied Remove Ads purchase identifiers. If another
  /// active purchase remains, the entitlement stays enabled.
  Future<bool> revokeRemoveAds({
    required String productId,
    required String purchaseId,
    Set<String> aliasIds = const {},
  }) async {
    final ids = {purchaseId, ...aliasIds}
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (productId != PurchaseCatalog.removeAdsId || ids.isEmpty) return false;

    final wasOwned = removeAds;
    final wasActive = ids.any(removeAdsPurchaseIds.contains);
    final revokedBefore = revokedPurchaseIds.length;
    revokedPurchaseIds.addAll(ids);
    removeAdsPurchaseIds.removeAll(ids);
    removeAds = removeAdsPurchaseIds.isNotEmpty;

    final changed = revokedPurchaseIds.length != revokedBefore ||
        wasOwned != removeAds ||
        wasActive;
    if (changed) await _persist();
    if (wasOwned != removeAds) notifyListeners();
    return wasActive;
  }

  Future<bool> buyPack(List<CardDef> cards) async {
    if (!canBuyPack) return false;
    gold -= packCost;
    _rollSeason();
    if (seasonXp < Season.tierCount * Season.xpPerTier) {
      seasonXp += Season.xpPerPack;
    }
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

  /// Saves a deck, optionally under a new name.
  ///
  /// [replacing] is the name the deck was opened under. Editing a deck and
  /// giving it a different name is a rename, not a second deck -- without
  /// this the old entry stayed behind, and since nothing could delete it, it
  /// stayed forever.
  Future<void> saveDeck(String name, List<String> cardIds,
      {String? replacing}) async {
    if (replacing != null && replacing != name) decks.remove(replacing);
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

  Future<void> setGuestMode(bool on) async {
    guestMode = on;
    await _persist();
    notifyListeners();
  }

  Future<void> setAccountLinked(bool on) async {
    accountLinked = on;
    await _persist();
    notifyListeners();
  }

  Future<void> setAudio({
    bool? music,
    bool? sfx,
    bool? voice,
    bool? haptics,
  }) async {
    if (music != null) musicOn = music;
    if (sfx != null) sfxOn = sfx;
    if (voice != null) voiceOn = voice;
    if (haptics != null) hapticsOn = haptics;
    await _persist();
    notifyListeners();
  }

  // ── daily gauntlet ───────────────────────────────────────────────────

  /// True once today's attempt has been used up.
  bool gauntletDoneFor(String dayId) =>
      gauntletDay == dayId && gauntletFinished;

  /// True when an attempt was opened today and never finished.
  ///
  /// The match is deterministic, so this can be resumed rather than forfeited:
  /// a flat battery must not cost the player their one attempt. What it may
  /// not do is start over, which is why this is recorded on entry.
  bool gauntletResumableFor(String dayId) =>
      gauntletDay == dayId && gauntletStarted && !gauntletFinished;

  /// Records that the attempt has been opened. Called before the first card
  /// is seen, so backing out cannot be used to reroll a bad-looking day.
  Future<void> beginGauntlet(String dayId) async {
    if (gauntletDay != dayId) {
      gauntletDay = dayId;
      gauntletFinished = false;
      gauntletWon = false;
      gauntletHealthLeft = 0;
      gauntletTurns = 0;
    }
    gauntletStarted = true;
    await _persist();
    notifyListeners();
  }

  /// Banks the result and pays out. Returns the streak *after* this attempt.
  ///
  /// The streak counts finished attempts on consecutive days. Playing twice in
  /// one day cannot advance it, and neither can finishing an attempt opened on
  /// an older day.
  Future<int> finishGauntlet({
    required String dayId,
    required bool won,
    required int healthLeft,
    required int turns,
    required int gold,
    required int shards,
  }) async {
    if (gauntletDay == dayId && gauntletFinished) return gauntletStreak;

    gauntletDay = dayId;
    gauntletStarted = true;
    gauntletFinished = true;
    gauntletWon = won;
    gauntletHealthLeft = healthLeft;
    gauntletTurns = turns;

    if (gauntletLastDay != dayId) {
      final yesterday = DateTime.tryParse(dayId)?.subtract(
        const Duration(days: 1),
      );
      final yesterdayId = yesterday == null
          ? ''
          : '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}'
              '-${yesterday.day.toString().padLeft(2, '0')}';
      gauntletStreak = gauntletLastDay == yesterdayId ? gauntletStreak + 1 : 1;
      gauntletLastDay = dayId;
    }

    this.gold += gold;
    this.shards += shards;
    await _persist();
    notifyListeners();
    return gauntletStreak;
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

  // ── cloud save snapshot ───────────────────────────────────────────────

  /// True when this device holds progress a cloud restore would destroy.
  ///
  /// A fresh install has none of this, which is the only case where adopting a
  /// cloud save outright is safe.
  bool get hasLocalProgress =>
      totalWins > 0 ||
      totalPacks > 0 ||
      chaptersDone.isNotEmpty ||
      clearedBattles.isNotEmpty ||
      achievements.isNotEmpty;

  /// Complete profile snapshot for cloud save.
  ///
  /// Wider than [exportCode], which is a portable share code: this keeps device
  /// settings and the purchase ledger so a restored install resumes exactly
  /// where it left off and cannot re-grant Gold it already delivered.
  Map<String, dynamic> toSnapshot() => {
        'gold': gold,
        'shards': shards,
        'owned': owned,
        'chapterStage': chapterStage,
        'chaptersDone': chaptersDone.toList(),
        'clearedBattles': clearedBattles.toList(),
        'decks': decks,
        'seasonId': seasonId,
        'seasonXp': seasonXp,
        'seasonClaimed': seasonClaimed,
        'quests': quests,
        'questDate': questDate,
        'tutorialSeen': tutorialSeen,
        'musicOn': musicOn,
        'sfxOn': sfxOn,
        'voiceOn': voiceOn,
        'hapticsOn': hapticsOn,
        'colorblind': colorblind,
        'reduceMotion': reduceMotion,
        'loginStreak': loginStreak,
        'gauntletDay': gauntletDay,
        'gauntletStarted': gauntletStarted,
        'gauntletFinished': gauntletFinished,
        'gauntletWon': gauntletWon,
        'gauntletHealthLeft': gauntletHealthLeft,
        'gauntletTurns': gauntletTurns,
        'gauntletStreak': gauntletStreak,
        'gauntletLastDay': gauntletLastDay,
        'lastLoginDate': lastLoginDate,
        'totalWins': totalWins,
        'totalPacks': totalPacks,
        'achievements': achievements.toList(),
        'arenaBestWins': arenaBestWins,
        'processedPurchaseIds': processedPurchaseIds.toList(),
        'unverifiedPurchases': unverifiedPurchases.toList(),
        'revokedPurchaseIds': revokedPurchaseIds.toList(),
        'removeAds': removeAds,
        'removeAdsPurchaseIds': removeAdsPurchaseIds.toList(),
      };

  /// Replaces the local profile with [data]. Fields missing from the snapshot
  /// keep their current value, so an older snapshot never blanks newer state.
  Future<void> applySnapshot(Map<String, dynamic> data) async {
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
    decks = (data['decks'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, [for (final id in v as List) id as String]));
    quests = [
      for (final q in data['quests'] as List? ?? const [])
        Map<String, dynamic>.from(q as Map),
    ];
    questDate = data['questDate'] as String? ?? questDate;
    seasonId = data['seasonId'] as String? ?? seasonId;
    seasonXp = data['seasonXp'] as int? ?? seasonXp;
    seasonClaimed = [
      for (final t in data['seasonClaimed'] as List? ?? const [])
        if (t is int) t,
    ];
    tutorialSeen = data['tutorialSeen'] as bool? ?? tutorialSeen;
    musicOn = data['musicOn'] as bool? ?? musicOn;
    sfxOn = data['sfxOn'] as bool? ?? sfxOn;
    voiceOn = data['voiceOn'] as bool? ?? voiceOn;
    hapticsOn = data['hapticsOn'] as bool? ?? hapticsOn;
    colorblind = data['colorblind'] as bool? ?? colorblind;
    reduceMotion = data['reduceMotion'] as bool? ?? reduceMotion;
    loginStreak = data['loginStreak'] as int? ?? loginStreak;
    gauntletDay = data['gauntletDay'] as String? ?? gauntletDay;
    gauntletStarted = data['gauntletStarted'] as bool? ?? gauntletStarted;
    gauntletFinished = data['gauntletFinished'] as bool? ?? gauntletFinished;
    gauntletWon = data['gauntletWon'] as bool? ?? gauntletWon;
    gauntletHealthLeft =
        data['gauntletHealthLeft'] as int? ?? gauntletHealthLeft;
    gauntletTurns = data['gauntletTurns'] as int? ?? gauntletTurns;
    gauntletStreak = data['gauntletStreak'] as int? ?? gauntletStreak;
    gauntletLastDay = data['gauntletLastDay'] as String? ?? gauntletLastDay;
    lastLoginDate = data['lastLoginDate'] as String? ?? lastLoginDate;
    totalWins = data['totalWins'] as int? ?? totalWins;
    totalPacks = data['totalPacks'] as int? ?? totalPacks;
    achievements =
        (data['achievements'] as List? ?? const []).cast<String>().toSet();
    arenaBestWins = data['arenaBestWins'] as int? ?? arenaBestWins;
    // Union, never replace: an identifier this device already delivered must
    // stay known even if the snapshot predates it.
    processedPurchaseIds.addAll(
      (data['processedPurchaseIds'] as List? ?? const []).cast<String>(),
    );
    unverifiedPurchases.addAll(
      (data['unverifiedPurchases'] as List? ?? const []).cast<String>(),
    );
    revokedPurchaseIds.addAll(
      (data['revokedPurchaseIds'] as List? ?? const []).cast<String>(),
    );
    removeAdsPurchaseIds.addAll(
      (data['removeAdsPurchaseIds'] as List? ?? const []).cast<String>(),
    );
    // A cloud snapshot can add a known entitlement, but it must never revoke
    // a local Play purchase merely because the snapshot predates it.
    if (data['removeAds'] == true || removeAdsPurchaseIds.isNotEmpty) {
      removeAds = true;
    }
    await _persist();
    notifyListeners();
  }

  // ── save export / import (local backup) ───────────────────────────────
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
  // ── seasonal track ───────────────────────────────────────────────────

  /// Rolls the season over when the calendar has moved on.
  ///
  /// Called on every XP grant and whenever the season is displayed, so a
  /// player who leaves the game open across midnight on the first still sees
  /// the right month. Returns true when a reset happened.
  bool _rollSeason() {
    final now = Season.idFor(DateTime.now());
    if (seasonId == now) return false;
    seasonId = now;
    seasonXp = 0;
    seasonClaimed = [];
    return true;
  }

  int get seasonTier => Season.tierFor(seasonXp);

  /// Tiers reached but not yet collected.
  List<SeasonTier> get claimableTiers => [
        for (final t in Season.tiers)
          if (t.tier <= seasonTier && !seasonClaimed.contains(t.tier)) t,
      ];

  Future<void> claimSeasonTier(int tier) async {
    _rollSeason();
    if (tier > seasonTier || seasonClaimed.contains(tier)) return;
    final reward = Season.tiers.firstWhere((t) => t.tier == tier,
        orElse: () => const SeasonTier(0, 0));
    if (reward.tier == 0) return;
    gold += reward.gold;
    shards += reward.shards;
    seasonClaimed = [...seasonClaimed, tier];
    await _persist();
    notifyListeners();
  }

  /// Collects everything owed in one tap. Long absences otherwise mean
  /// tapping Claim eleven times, which is busywork, not a reward.
  Future<({int gold, int shards, int tiers})> claimAllSeasonTiers() async {
    _rollSeason();
    final owed = claimableTiers;
    if (owed.isEmpty) return (gold: 0, shards: 0, tiers: 0);
    var g = 0;
    var sh = 0;
    for (final t in owed) {
      g += t.gold;
      sh += t.shards;
    }
    gold += g;
    shards += sh;
    seasonClaimed = [...seasonClaimed, for (final t in owed) t.tier];
    await _persist();
    notifyListeners();
    return (gold: g, shards: sh, tiers: owed.length);
  }

  Future<void> trackQuest(String event) async {
    final events = {event, if (event.endsWith('_win')) 'battle_win'};
    var changed = false;

    // Season XP rides on the hook every win path already calls, so no screen
    // needs a second line to feed the track.
    final xp = Season.xpFor[event];
    if (xp != null) {
      if (_rollSeason()) changed = true;
      if (seasonXp < Season.tierCount * Season.xpPerTier) {
        seasonXp += xp;
        changed = true;
      }
    }
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
    'full_set': ('Completionist', 'Own all 192 cards', 2000),
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
    unlock('full_set', uniqueOwned >= 192);
    unlock('chapter_one', chaptersDone.contains('ch1'));
    unlock('saga_done', chaptersDone.length >= 5);
    unlock('pack_rat', totalPacks >= 10);
  }

  Future<void> _persist() async {
    await _prefs.setInt('gold', gold);
    await _prefs.setInt('shards', shards);
    await _prefs.setStringList(
        'processedPurchaseIds', processedPurchaseIds.toList());
    await _prefs.setStringList(
        'unverifiedPurchases', unverifiedPurchases.toList());
    await _prefs.setStringList(
        'revokedPurchaseIds', revokedPurchaseIds.toList());
    await _prefs.setBool('removeAds', removeAds);
    await _prefs.setStringList(
        'removeAdsPurchaseIds', removeAdsPurchaseIds.toList());
    await _prefs.setString('quests', json.encode(quests));
    await _prefs.setString('questDate', questDate);
    await _prefs.setString('owned', json.encode(owned));
    await _prefs.setString('chapterStage', json.encode(chapterStage));
    await _prefs.setStringList('chaptersDone', chaptersDone.toList());
    await _prefs.setStringList('clearedBattles', clearedBattles.toList());
    await _prefs.setString('decks', json.encode(decks));
    await _prefs.setBool('tutorialSeen', tutorialSeen);
    await _prefs.setBool('guestMode', guestMode);
    await _prefs.setBool('accountLinked', accountLinked);
    await _prefs.setBool('musicOn', musicOn);
    await _prefs.setBool('sfxOn', sfxOn);
    await _prefs.setBool('voiceOn', voiceOn);
    await _prefs.setBool('hapticsOn', hapticsOn);
    await _prefs.setString('seasonId', seasonId);
    await _prefs.setInt('seasonXp', seasonXp);
    await _prefs.setStringList(
        'seasonClaimed', [for (final t in seasonClaimed) '$t']);
    await _prefs.setBool('colorblind', colorblind);
    await _prefs.setBool('reduceMotion', reduceMotion);
    await _prefs.setInt('loginStreak', loginStreak);
    await _prefs.setString('gauntletDay', gauntletDay);
    await _prefs.setBool('gauntletStarted', gauntletStarted);
    await _prefs.setBool('gauntletFinished', gauntletFinished);
    await _prefs.setBool('gauntletWon', gauntletWon);
    await _prefs.setInt('gauntletHealthLeft', gauntletHealthLeft);
    await _prefs.setInt('gauntletTurns', gauntletTurns);
    await _prefs.setInt('gauntletStreak', gauntletStreak);
    await _prefs.setString('gauntletLastDay', gauntletLastDay);
    await _prefs.setString('lastLoginDate', lastLoginDate);
    await _prefs.setInt('totalWins', totalWins);
    await _prefs.setInt('totalPacks', totalPacks);
    await _prefs.setStringList('achievements', achievements.toList());
    await _prefs.setInt('arenaBestWins', arenaBestWins);
    await _prefs.setInt('battlesPlayed', battlesPlayed);
    await _prefs.setInt('adGoldClaims', adGoldClaims);
    await _prefs.setString('adGoldDate', adGoldDate);
  }

  /// How many rewarded Gold claims are left today.
  int get adGoldClaimsLeft =>
      adGoldDate == _today() ? adGoldDailyCap - adGoldClaims : adGoldDailyCap;

  bool get canClaimAdGold => adGoldClaimsLeft > 0;

  /// Count a finished battle, whatever the result. Only the first few matter
  /// (they hold interstitials off), so this stops persisting once past them.
  Future<void> recordBattlePlayed() async {
    if (battlesPlayed > 100) return;
    battlesPlayed += 1;
    await _persist();
    notifyListeners();
  }

  /// Pay out a watched rewarded video. Returns the Gold granted, or 0 when the
  /// daily cap is already used — the caller must not have shown an ad then.
  Future<int> claimAdGold() async {
    final today = _today();
    if (adGoldDate != today) {
      adGoldDate = today;
      adGoldClaims = 0;
    }
    if (adGoldClaims >= adGoldDailyCap) return 0;
    adGoldClaims += 1;
    gold += adGoldReward;
    await _persist();
    notifyListeners();
    return adGoldReward;
  }

  /// Record a finished Arena run, updating the best streak and paying a
  /// milestone Shard bonus. Returns the bonus granted.
  Future<int> recordArenaRun(int wins) async {
    if (wins > arenaBestWins) arenaBestWins = wins;
    final bonus = wins >= 7
        ? 300
        : wins >= 5
            ? 150
            : wins >= 3
                ? 60
                : 0;
    shards += bonus;
    await _persist();
    notifyListeners();
    return bonus;
  }
}
