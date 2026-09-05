import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'about/about_screen.dart';
import 'auth/login_screen.dart';
import 'card_render/card_widget.dart';
import 'collection/collection_screen.dart';
import 'deckbuilder/decks_screen.dart';
import 'duel/coin_flip.dart';
import 'duel/duel_controller.dart';
import 'duel/duel_screen.dart';
import 'forge/forge_screen.dart';
import 'arena/arena_screen.dart';
import 'opening_cinematic.dart';
import 'packs/booster_screen.dart';
import 'pvp/pvp_screen.dart';
import 'progress/achievements_screen.dart';
import 'quests/quests_screen.dart';
import 'services/ad_service.dart';
import 'services/ad_result_flow.dart';
import 'gauntlet/daily_gauntlet.dart';
import 'gauntlet/gauntlet_screen.dart';
import 'season/season_screen.dart';
import 'services/audio_manager.dart';
import 'services/haptics.dart';
import 'services/auth_service.dart';
import 'services/backend_config.dart';
import 'services/cloud_sync_service.dart';
import 'services/gold_purchase_service.dart';
import 'services/remove_ads_purchase_service.dart';
import 'services/save_service.dart';
import 'services/telemetry_service.dart';
import 'splash_screen.dart';
import 'story/story_screen.dart';
import 'theme.dart';
import 'tutorial/tutorial_screen.dart';
import 'widgets/delete_account_tile.dart';
import 'widgets/remove_ads_offer.dart';
import 'widgets/privacy_options_tile.dart';

Future<void> main() async {
  // Everything runs inside the guarded zone so an error escaping an async gap
  // reaches a report instead of vanishing. Reporting never blocks startup.
  TelemetryService.instance.captureErrors(() async {
    await _boot();
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The backend is an enhancement, never a gate: a failure here leaves the
  // game running exactly as it did before, straight from local storage.
  if (BackendConfig.hasBackend) {
    try {
      await Supabase.initialize(
        url: BackendConfig.url,
        publishableKey: BackendConfig.publishableKey,
      );
    } catch (error) {
      debugPrint('Backend unavailable, continuing offline: $error');
    }
  }

  unawaited(TelemetryService.instance.init().then(
    (_) => TelemetryService.instance.track('app_opened'),
  ));

  runApp(const ShardfallApp());
}

class ShardfallApp extends StatelessWidget {
  const ShardfallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHARDFALL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const SplashScreen(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  CardLibrary? _library;
  SaveService? _save;
  GoldPurchaseService? _purchases;
  RemoveAdsPurchaseService? _removeAdsPurchases;
  AdService? _ads;
  AuthService? _auth;
  CloudSyncService? _cloud;

  static const _dominionKeys = [
    ('VERDANCE', Dominion.verdance),
    ('PYRE', Dominion.pyre),
    ('TIDE', Dominion.tide),
    ('DAWN', Dominion.dawn),
    ('GLOOM', Dominion.gloom),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _ads?.dispose();
    _removeAdsPurchases?.dispose();
    _purchases?.dispose();
    _cloud?.dispose();
    _auth?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume the ambient bed when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      AudioManager.instance.ensurePlaying();
    } else if (state == AppLifecycleState.paused) {
      // Music must not keep playing into someone else's app.
      unawaited(AudioManager.instance.pauseMusic());
      // Leaving the app is the natural moment to back the profile up. An
      // unresolved conflict is left alone so it cannot silently pick a winner.
      final cloud = _cloud;
      if (cloud != null && !cloud.cloudSaveConflict) {
        unawaited(cloud.pushSave());
      }
    }
  }

  Future<void> _load() async {
    final jsonStr = await rootBundle.loadString('assets/data/set01.json');
    final library = CardLibrary.fromJsonString(jsonStr);
    final save = await SaveService.load(library);
    save.addListener(() {
      if (mounted) setState(() {});
    });
    await AudioManager.instance.init(
      music: save.musicOn,
      sfx: save.sfxOn,
      voice: save.voiceOn,
    );
    CardWidget.colorblindLabels = save.colorblind;
    MotionPrefs.reduce = save.reduceMotion;
    Haptics.enabled = save.hapticsOn;
    final auth = AuthService();
    final cloud = CloudSyncService(save: save, auth: auth);
    final purchases = GoldPurchaseService(
      save: save,
      verifier: cloud.verifyPurchase,
    );
    final removeAdsPurchases = RemoveAdsPurchaseService(
      save: save,
      verifier: cloud.verifyPurchase,
    );
    final ads = AdService(save: save);
    // The menu shows offers that only exist once an ad is loaded (FREE GOLD),
    // and loading finishes long after this screen is first built. Without
    // listening here the tile would never appear, however ready the ad was.
    ads.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _library = library;
      _save = save;
      _purchases = purchases;
      _removeAdsPurchases = removeAdsPurchases;
      _ads = ads;
      _auth = auth;
      _cloud = cloud;
    });
    // The silent re-auth at startup keys off this flag; without it a Google
    // prompt could surface mid-cinematic for a player who never signed in.
    auth.accountLinked = save.accountLinked;
    unawaited(purchases.initialize());
    unawaited(removeAdsPurchases.initialize());
    unawaited(_syncBackend(auth, cloud));
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!save.tutorialSeen) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (ctx) =>
                  OpeningCinematic(onDone: () => Navigator.of(ctx).pop()),
            ),
          );
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => TutorialScreen(library: library)),
          );
          await save.markTutorialSeen();
        }
        if (!mounted) return;
        await _maybeShowLogin();
        _showProgressToasts();
        // Consent/ads must wait until this Activity is showing. Starting UMP
        // during the cinematic used to crash the closed-test build.
        unawaited(_startAds(ads));
      });
    }
  }

  Future<void> _startAds(AdService ads) async {
    try {
      await ads.initialize();
      await ads.preloadInterstitial();
      await ads.preloadRewarded();
    } catch (error) {
      debugPrint('Ads unavailable: $error');
    }
  }

  /// The one-time account choice, shown after the intro on a first run or
  /// right after the menu loads. Skipped for builds without a backend, for
  /// players already signed in, and for guests who already chose — their
  /// answer is remembered, so this never becomes a nag screen.
  Future<void> _maybeShowLogin() async {
    final auth = _auth;
    final save = _save;
    final cloud = _cloud;
    if (auth == null || save == null) return;
    if (!BackendConfig.hasGoogleSignIn) return;
    if (auth.isSignedIn || save.guestMode) return;

    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(auth: auth, save: save),
      ),
    );
    if (linked != true || cloud == null || !mounted) return;

    await cloud.syncOnSignIn();
    if (!mounted) return;
    setState(() {});
    _reportSync(cloud);
  }

  /// Re-establishes a previous session and pulls back anything paid for.
  Future<void> _syncBackend(AuthService auth, CloudSyncService cloud) async {
    await auth.restoreSession();
    if (!auth.isSignedIn || !mounted) return;

    await cloud.syncOnSignIn();
    if (!mounted) return;
    setState(() {});
    _reportSync(cloud);
  }

  /// A visible home for the account: who is playing, and the way out.
  /// Signing out used to hide inside the settings sheet, which read as
  /// there being no logout at all.
  void _showAccount() {
    final auth = _auth;
    if (auth == null) return;
    final signedIn = auth.isSignedIn;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(
          signedIn ? 'Signed in' : 'Playing as guest',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Text(
          signedIn
              ? '${auth.displayName ?? 'Google account'}\nPvP and Gold '
                    'purchases are unlocked, and your progress is backed up.'
              : 'Your progress lives only on this device. Link a Google '
                    'account to unlock PvP and Gold purchases.',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_toggleAccount());
            },
            child: Text(signedIn ? 'Sign out' : 'Sign in with Google'),
          ),
        ],
      ),
    );
  }

  /// Signs in, or signs out after saving one last time.
  Future<void> _toggleAccount() async {
    final auth = _auth;
    final cloud = _cloud;
    if (auth == null || cloud == null) return;

    if (auth.isSignedIn) {
      await cloud.pushSave();
      await auth.signOut();
      await _save?.setAccountLinked(false);
      auth.accountLinked = false;
      if (mounted) setState(() {});
      return;
    }

    final signedIn = await auth.signIn();
    if (!mounted) return;

    if (!signedIn) {
      final failure = auth.message;
      if (failure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure)));
      }
      return;
    }

    await _save?.setAccountLinked(true);
    auth.accountLinked = true;
    await cloud.syncOnSignIn();
    if (!mounted) return;
    setState(() {});
    _reportSync(cloud);
  }

  Future<bool> _deleteAccount() async {
    final auth = _auth;
    final save = _save;
    if (auth == null || save == null || !auth.isSignedIn) return false;

    final deleted = await auth.deleteAccount();
    if (!deleted) return false;

    await save.setAccountLinked(false);
    await save.setGuestMode(true);
    if (mounted) setState(() {});
    return true;
  }

  void _reportSync(CloudSyncService cloud) {
    if (cloud.cloudSaveConflict) {
      _showCloudConflict(cloud);
      return;
    }
    if (cloud.recoveredGold > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cloud.recoveredGold} Gold restored to your balance.',
          ),
        ),
      );
    }
  }

  /// Both the account and this device hold progress. Never choose for the
  /// player — whichever side loses, someone loses a collection.
  void _showCloudConflict(CloudSyncService cloud) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text(
          'Two saves found',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: const Text(
          'Your account already has a save, and this device has progress of '
          'its own. Keeping one replaces the other.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await cloud.resolveWithLocalSave();
              if (mounted) setState(() {});
            },
            child: const Text('Keep this device'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await cloud.resolveWithCloudSave();
              if (mounted) setState(() {});
            },
            child: const Text('Use my account save'),
          ),
        ],
      ),
    );
  }

  /// Surface the daily login bonus and any freshly-unlocked achievements.
  void _showProgressToasts() {
    if (!mounted || _save == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final bonus = _save!.pendingDailyBonus;
    if (bonus > 0) {
      _save!.clearPendingDailyBonus();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Daily login: +$bonus gold  ·  ${_save!.loginStreak}-day streak 🔥',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    for (final id in _save!.pendingAchievements) {
      final a = SaveService.achievementCatalogue[id];
      if (a != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🏆 ${a.$1} unlocked — +${a.$3} gold'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    _save!.pendingAchievements.clear();
  }

  /// Replay the opening lore cinematic from the menu.
  Future<void> _playCinematic() async {
    AudioManager.instance.tap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) =>
            OpeningCinematic(onDone: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      // Without these two the sheet is capped at 9/16 of the screen and its
      // Column simply runs off the bottom with no way to scroll: every item
      // past Remove Ads — Delete account, About — was unreachable.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text(
                  'Music',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                value: _save!.musicOn,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setAudio(music: v);
                  AudioManager.instance.setMusic(v);
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Sound effects',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                value: _save!.sfxOn,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setAudio(sfx: v);
                  AudioManager.instance.setSfx(v);
                  if (v) AudioManager.instance.tap();
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Vibration',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Touch feedback in battle',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                value: _save!.hapticsOn,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setAudio(haptics: v);
                  Haptics.enabled = v;
                  if (v) Haptics.select();
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Narration',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Spoken story and dialogue',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                value: _save!.voiceOn,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setAudio(voice: v);
                  AudioManager.instance.setVoice(v);
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Colorblind rarity labels',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Show C/U/R/E/L on cards',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: _save!.colorblind,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setColorblind(v);
                  CardWidget.colorblindLabels = v;
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Reduce motion',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Fewer shakes and flying animations',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: _save!.reduceMotion,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setReduceMotion(v);
                  MotionPrefs.reduce = v;
                },
              ),
              if (_removeAdsPurchases != null) ...[
                const Divider(color: AppTheme.panelBorder),
                RemoveAdsOffer(
                  purchaseService: _removeAdsPurchases!,
                  save: _save!,
                ),
              ],
              if (_ads != null)
                ListenableBuilder(
                  listenable: _ads!,
                  builder: (_, _) => PrivacyOptionsTile(ads: _ads!),
                ),
              if (_auth?.isSignedIn == true)
                DeleteAccountTile(onDelete: _deleteAccount),
              ListTile(
                leading:
                    const Icon(Icons.info_outline, color: Color(0xFFC9A86A)),
                title: const Text('About',
                    style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Developer, version, rate and share',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                onTap: () {
                  AudioManager.instance.tap();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AboutScreen(),
                  ));
                },
              ),
              const Divider(color: AppTheme.panelBorder),
              ListTile(
                leading: const Icon(
                  Icons.movie_creation_outlined,
                  color: Color(0xFFC9A86A),
                ),
                title: const Text(
                  'Watch opening cinematic',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Replay the story of the Sundering',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _playCinematic();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: Color(0xFF9FB2BC),
                ),
                title: const Text(
                  'How to play',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Replay the onboarding guide',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  AudioManager.instance.tap();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TutorialScreen(library: _library),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: Color(0xFF9FB2BC)),
                title: const Text(
                  'Back up / restore progress',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Export or import a save code',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSaveBackup();
                },
              ),
              if (BackendConfig.hasGoogleSignIn) ...[
                const Divider(color: AppTheme.panelBorder),
                ListTile(
                  leading: Icon(
                    _auth!.isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                    color: _auth!.isSignedIn
                        ? const Color(0xFF7FBF7F)
                        : const Color(0xFF9FB2BC),
                  ),
                  title: Text(
                    _auth!.isSignedIn ? 'Sign out' : 'Sign in with Google',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _auth!.isSignedIn
                        ? _auth!.displayName ?? 'Signed in'
                        : 'Keeps purchased Gold if you reinstall',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_toggleAccount());
                  },
                ),
              ],
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSaveBackup() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text(
          'Back up / restore',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Copy your save code to keep progress, or paste one to restore. (Cloud sync arrives with online play.)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'Paste SFSAVE-... to import',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _save!.exportCode()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Save code copied to clipboard.')),
              );
            },
            child: const Text('Copy my code'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _save!.importCode(ctrl.text.trim());
              if (!mounted) return;
              Navigator.pop(context);
              CardWidget.colorblindLabels = _save!.colorblind;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Progress restored.' : 'Invalid save code.',
                  ),
                ),
              );
              setState(() {});
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  String _enemyNameFor(String key) => switch (key) {
    'VERDANCE' => 'Thornmaw, Wild Patriarch',
    'PYRE' => 'Kaelis Emberborn',
    'TIDE' => 'Archivist Numen',
    'DAWN' => 'Seraphel the Lightkeeper',
    'GLOOM' => 'Ravenna Duskveil',
    _ => 'Shardcaller',
  };

  void _pickDominionAndDuel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_save!.decks.isNotEmpty) ...[
                const Text(
                  'YOUR DECKS',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final name in _save!.decks.keys)
                  _savedDeckButton(sheetContext, name),
                const SizedBox(height: 18),
                const Divider(color: AppTheme.panelBorder),
                const SizedBox(height: 10),
              ],
              const Text(
                'OR A STARTER DOMINION',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final (key, dom) in _dominionKeys)
                    _dominionButton(sheetContext, key, dom),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchDuel(List<CardDef> playerDeck) async {
    final enemyKey =
        _dominionKeys[math.Random().nextInt(_dominionKeys.length)].$1;
    final firstPlayer = await showCoinFlip(context);
    if (!mounted) return;
    final controller = DuelController(
      playerDeck: playerDeck,
      enemyDeck: _library!.buildStarterDeck(enemyKey),
      firstPlayer: firstPlayer,
    );
    final won = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DuelScreen(
          controller: controller,
          enemyName: _enemyNameFor(enemyKey),
        ),
      ),
    );
    if (won != true && _save != null) {
      // A loss still feeds the season. Nothing else changes: 'battle_loss'
      // matches no quest and does not touch the win counter.
      await _save!.trackQuest('battle_loss');
    }
    if (won == true && _save != null) {
      await _save!.addGold(SaveService.duelWinGold);
      await _save!.trackQuest('duel_win');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Victory! +${SaveService.duelWinGold} gold'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    await showPostResultInterstitial(_ads);
  }

  Widget _savedDeckButton(BuildContext sheetContext, String name) {
    final ids = _save!.decks[name]!;
    return GestureDetector(
      onTap: () {
        Navigator.of(sheetContext).pop();
        final deck = [for (final id in ids) _library!.card(id)];
        _launchDuel(deck);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFC9A86A).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.dashboard_customize,
              color: Color(0xFFE6CE96),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${ids.length} cards',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dominionButton(BuildContext sheetContext, String key, Dominion dom) {
    final style = DominionStyle.of(dom);
    return GestureDetector(
      onTap: () {
        Navigator.of(sheetContext).pop();
        _launchDuel(_library!.buildStarterDeck(key));
      },
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: style.frame,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.glow.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(style.icon, color: style.glow, size: 28),
            const SizedBox(height: 7),
            Text(
              key,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // AI key art background
          Image.asset(
            'assets/ui/menu_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.6,
                  colors: [AppTheme.bgTop, AppTheme.bgBottom],
                ),
              ),
            ),
          ),
          // scrim for readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: _library == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 30),
                        // Title — single line, always fits
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [
                                Color(0xFFF4ECD4),
                                Color(0xFFC9A86A),
                                Color(0xFF8A713A),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(r),
                            child: const Text(
                              'SHARDFALL',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 58,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 16,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SET I — THE SUNDERING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD8CCAE),
                            fontSize: 11,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFFC9A86A,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Color(0xFFE3B341),
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${_save?.gold ?? 0}',
                                  style: const TextStyle(
                                    color: Color(0xFFF0E4C0),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.hexagon,
                                  color: Color(0xFF8FE3FF),
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_save?.shards ?? 0}',
                                  style: const TextStyle(
                                    color: Color(0xFFCFEFFF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: const Color(0x55C9A86A),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.style,
                                  color: Color(0xFF9FB2BC),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_save?.uniqueOwned ?? 0}/${_library?.byId.length ?? 0}',
                                  style: const TextStyle(
                                    color: Color(0xFFCFD6DE),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: const Color(0x55C9A86A),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _showSettings,
                                  child: const Icon(
                                    Icons.settings,
                                    color: Color(0xFF9FB2BC),
                                    size: 16,
                                  ),
                                ),
                                if (BackendConfig.hasGoogleSignIn) ...[
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _showAccount,
                                    child: Icon(
                                      _auth?.isSignedIn == true
                                          ? Icons.account_circle
                                          : Icons.person_outline,
                                      color: _auth?.isSignedIn == true
                                          ? const Color(0xFF7FBF7F)
                                          : const Color(0xFF9FB2BC),
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(top: 56, bottom: 16),
                            children: [
                              _heroCard(
                                icon: Icons.auto_stories,
                                title: 'STORY',
                                subtitle: 'Chapter I — The Waking Grove',
                                color: DominionStyle.of(Dominion.verdance).glow,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoryScreen(
                                      library: _library!,
                                      save: _save!,
                                      adService: _ads!,
                                    ),
                                  ),
                                ),
                              ),
                              _heroCard(
                                icon: Icons.sports_kabaddi,
                                title: 'DUEL',
                                subtitle: 'Skirmish against the AI',
                                color: AppTheme.danger,
                                onTap: _pickDominionAndDuel,
                              ),
                              const SizedBox(height: 14),
                              GridView.count(
                                crossAxisCount: 3,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.92,
                                children: [
                                  if (_ads?.rewardedReady == true &&
                                      (_save?.canClaimAdGold ?? false))
                                    _tile(
                                      icon: Icons.play_circle_outline,
                                      label: 'FREE GOLD',
                                      color: const Color(0xFF7FE0A8),
                                      badge: _save?.adGoldClaimsLeft ?? 0,
                                      onTap: _watchForGold,
                                    ),
                                  _tile(
                                    icon: Icons.bolt,
                                    label: 'GAUNTLET',
                                    color: const Color(0xFF8FE3FF),
                                    // Badges when today's attempt is still
                                    // unspent -- the one number on this menu
                                    // that expires at midnight.
                                    badge: _save != null &&
                                            !_save!.gauntletDoneFor(
                                                DailyGauntlet.idFor(
                                                    DateTime.now()))
                                        ? 1
                                        : 0,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => GauntletScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.military_tech,
                                    label: 'SEASON',
                                    color: const Color(0xFFC9A86A),
                                    badge:
                                        _save?.claimableTiers.length ?? 0,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            SeasonScreen(save: _save!),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.assignment_turned_in,
                                    label: 'QUESTS',
                                    color: const Color(0xFFE3B341),
                                    badge: _save?.claimableQuests ?? 0,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            QuestsScreen(save: _save!, adService: _ads!),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.style,
                                    label: 'COLLECTION',
                                    color: DominionStyle.of(Dominion.tide).glow,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => CollectionScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.dashboard_customize,
                                    label: 'DECKS',
                                    color: DominionStyle.of(
                                      Dominion.verdance,
                                    ).glow,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => DecksScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.hardware,
                                    label: 'FORGE',
                                    color: const Color(0xFF8FE3FF),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ForgeScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.card_giftcard,
                                    label: 'BOOSTERS',
                                    color: const Color(0xFFC9A86A),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BoosterScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads!,
                                          purchaseService: _purchases!,
                                          auth: _auth!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.military_tech,
                                    label: 'ARENA',
                                    color: AppTheme.danger,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ArenaScreen(
                                          library: _library!,
                                          save: _save!,
                                          adService: _ads!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.sports_esports,
                                    label: 'PVP',
                                    color: const Color(0xFF8FE3FF),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PvpLobbyScreen(
                                          library: _library!,
                                          save: _save!,
                                          auth: _auth!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.emoji_events,
                                    label: 'AWARDS',
                                    color: const Color(0xFFE3B341),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AchievementsScreen(save: _save!, adService: _ads!),
                                      ),
                                    ),
                                  ),
                                  _tile(
                                    icon: Icons.school,
                                    label: 'HOW TO PLAY',
                                    color: DominionStyle.of(Dominion.dawn).glow,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TutorialScreen(library: _library),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Set 1: The Sundering — PvE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0x779A97A8),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Large featured button (STORY / DUEL) — the primary actions.
  Widget _heroCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withValues(alpha: 0.20),
              Colors.black.withValues(alpha: 0.30),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 16),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: 0.45), Colors.transparent],
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      color: Colors.white,
                      fontSize: 19,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill,
              color: color.withValues(alpha: 0.85),
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  /// Compact icon tile for the secondary actions grid.
  /// Play a rewarded video and pay out the Gold, but only once Google
  /// confirms the player actually watched it.
  Future<void> _watchForGold() async {
    final ads = _ads;
    final save = _save;
    if (ads == null || save == null) return;
    AudioManager.instance.tap();

    if (!save.canClaimAdGold) {
      _toast('You have taken all of today\'s free Gold. Back tomorrow.');
      return;
    }

    final watched = await ads.showRewarded();
    if (!mounted) return;
    if (!watched) {
      unawaited(TelemetryService.instance.track('rewarded_gold_abandoned'));
      _toast('No Gold this time — the video needs to finish.');
      return;
    }

    final granted = await save.claimAdGold();
    if (!mounted) return;
    if (granted > 0) {
      unawaited(TelemetryService.instance.track(
          'rewarded_gold_claimed', {'left_today': save.adGoldClaimsLeft}));
      AudioManager.instance.reward();
      _toast('+$granted Gold. ${save.adGoldClaimsLeft} left today.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    // Without this the whole menu is invisible to a screen reader: the
    // tiles are gesture detectors around icons, which announce nothing.
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge waiting' : label,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.38),
              Colors.black.withValues(alpha: 0.16),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(color: color.withValues(alpha: 0.8)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}
