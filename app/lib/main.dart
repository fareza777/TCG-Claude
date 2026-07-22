import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'card_render/card_widget.dart';
import 'collection/collection_screen.dart';
import 'deckbuilder/deck_builder_screen.dart';
import 'duel/coin_flip.dart';
import 'duel/duel_controller.dart';
import 'duel/duel_screen.dart';
import 'forge/forge_screen.dart';
import 'arena/arena_screen.dart';
import 'opening_cinematic.dart';
import 'packs/booster_screen.dart';
import 'progress/achievements_screen.dart';
import 'quests/quests_screen.dart';
import 'services/audio_manager.dart';
import 'services/save_service.dart';
import 'splash_screen.dart';
import 'story/story_screen.dart';
import 'theme.dart';
import 'tutorial/tutorial_screen.dart';

void main() {
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume the ambient bed when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      AudioManager.instance.ensurePlaying();
    }
  }

  Future<void> _load() async {
    final jsonStr = await rootBundle.loadString('assets/data/set01.json');
    final library = CardLibrary.fromJsonString(jsonStr);
    final save = await SaveService.load(library);
    save.addListener(() {
      if (mounted) setState(() {});
    });
    await AudioManager.instance
        .init(music: save.musicOn, sfx: save.sfxOn);
    CardWidget.colorblindLabels = save.colorblind;
    MotionPrefs.reduce = save.reduceMotion;
    setState(() {
      _library = library;
      _save = save;
    });
    if (!save.tutorialSeen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (ctx) =>
                OpeningCinematic(onDone: () => Navigator.of(ctx).pop())));
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const TutorialScreen()));
        await save.markTutorialSeen();
        _showProgressToasts();
      });
    } else if (mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showProgressToasts());
    }
  }

  /// Surface the daily login bonus and any freshly-unlocked achievements.
  void _showProgressToasts() {
    if (!mounted || _save == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final bonus = _save!.pendingDailyBonus;
    if (bonus > 0) {
      _save!.clearPendingDailyBonus();
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Daily login: +$bonus gold  ·  ${_save!.loginStreak}-day streak 🔥'),
        duration: const Duration(seconds: 3),
      ));
    }
    for (final id in _save!.pendingAchievements) {
      final a = SaveService.achievementCatalogue[id];
      if (a != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('🏆 ${a.$1} unlocked — +${a.$3} gold'),
          duration: const Duration(seconds: 3),
        ));
      }
    }
    _save!.pendingAchievements.clear();
  }

  /// Replay the opening lore cinematic from the menu.
  Future<void> _playCinematic() async {
    AudioManager.instance.tap();
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (ctx) =>
            OpeningCinematic(onDone: () => Navigator.of(ctx).pop())));
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Music',
                    style: TextStyle(color: AppTheme.textPrimary)),
                value: _save!.musicOn,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setAudio(music: v);
                  AudioManager.instance.setMusic(v);
                },
              ),
              SwitchListTile(
                title: const Text('Sound effects',
                    style: TextStyle(color: AppTheme.textPrimary)),
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
                title: const Text('Colorblind rarity labels',
                    style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Show C/U/R/E/L on cards',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                value: _save!.colorblind,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setColorblind(v);
                  CardWidget.colorblindLabels = v;
                },
              ),
              SwitchListTile(
                title: const Text('Reduce motion',
                    style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Fewer shakes and flying animations',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                value: _save!.reduceMotion,
                activeThumbColor: const Color(0xFFC9A86A),
                onChanged: (v) {
                  setSheet(() {});
                  _save!.setReduceMotion(v);
                  MotionPrefs.reduce = v;
                },
              ),
              const Divider(color: AppTheme.panelBorder),
              ListTile(
                leading: const Icon(Icons.movie_creation_outlined,
                    color: Color(0xFFC9A86A)),
                title: const Text('Watch opening cinematic',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: const Text('Replay the story of the Sundering',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _playCinematic();
                },
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined,
                    color: Color(0xFF9FB2BC)),
                title: const Text('How to play',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: const Text('Replay the onboarding guide',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  AudioManager.instance.tap();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const TutorialScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: Color(0xFF9FB2BC)),
                title: const Text('Back up / restore progress',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: const Text('Export or import a save code',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _showSaveBackup();
                },
              ),
            ],
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
        title: const Text('Back up / restore',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Copy your save code to keep progress, or paste one to restore. (Cloud sync arrives with online play.)',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              decoration: const InputDecoration(hintText: 'Paste SFSAVE-... to import'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _save!.exportCode()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Save code copied to clipboard.')));
            },
            child: const Text('Copy my code'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _save!.importCode(ctrl.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              CardWidget.colorblindLabels = _save!.colorblind;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Progress restored.'
                      : 'Invalid save code.')));
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_save!.decks.isNotEmpty) ...[
                const Text('YOUR DECKS',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final name in _save!.decks.keys)
                  _savedDeckButton(sheetContext, name),
                const SizedBox(height: 18),
                const Divider(color: AppTheme.panelBorder),
                const SizedBox(height: 10),
              ],
              const Text('OR A STARTER DOMINION',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800)),
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
    final won = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DuelScreen(
          controller: controller, enemyName: _enemyNameFor(enemyKey)),
    ));
    if (won == true && _save != null) {
      await _save!.addGold(SaveService.duelWinGold);
      await _save!.trackQuest('duel_win');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Victory! +${SaveService.duelWinGold} gold'),
          duration: const Duration(seconds: 2),
        ));
      }
    }
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
              color: const Color(0xFFC9A86A).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize,
                color: Color(0xFFE6CE96), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Text('${ids.length} cards',
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _dominionButton(
      BuildContext sheetContext, String key, Dominion dom) {
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
              colors: style.frame),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.glow.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(style.icon, color: style.glow, size: 28),
            const SizedBox(height: 7),
            Text(key,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800)),
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
                                Color(0xFF8A713A)
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
                                      offset: Offset(0, 3)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('SET I — THE SUNDERING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFD8CCAE),
                                fontSize: 11,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 8)
                                ])),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFC9A86A)
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on,
                                    color: Color(0xFFE3B341), size: 17),
                                const SizedBox(width: 7),
                                Text('${_save?.gold ?? 0}',
                                    style: const TextStyle(
                                        color: Color(0xFFF0E4C0),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 12),
                                const Icon(Icons.hexagon,
                                    color: Color(0xFF8FE3FF), size: 14),
                                const SizedBox(width: 5),
                                Text('${_save?.shards ?? 0}',
                                    style: const TextStyle(
                                        color: Color(0xFFCFEFFF),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 12),
                                Container(
                                    width: 1,
                                    height: 14,
                                    color: const Color(0x55C9A86A)),
                                const SizedBox(width: 12),
                                const Icon(Icons.style,
                                    color: Color(0xFF9FB2BC), size: 15),
                                const SizedBox(width: 6),
                                Text(
                                    '${_save?.uniqueOwned ?? 0}/${_library?.byId.length ?? 0}',
                                    style: const TextStyle(
                                        color: Color(0xFFCFD6DE),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                                Container(
                                    width: 1,
                                    height: 14,
                                    color: const Color(0x55C9A86A)),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _showSettings,
                                  child: const Icon(Icons.settings,
                                      color: Color(0xFF9FB2BC), size: 16),
                                ),
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
                                    library: _library!, save: _save!)),
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
                            _tile(
                              icon: Icons.assignment_turned_in,
                              label: 'QUESTS',
                              color: const Color(0xFFE3B341),
                              badge: _save?.claimableQuests ?? 0,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        QuestsScreen(save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.style,
                              label: 'COLLECTION',
                              color: DominionStyle.of(Dominion.tide).glow,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => CollectionScreen(
                                        library: _library!, save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.dashboard_customize,
                              label: 'DECKS',
                              color: DominionStyle.of(Dominion.verdance).glow,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => DeckBuilderScreen(
                                        library: _library!, save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.hardware,
                              label: 'FORGE',
                              color: const Color(0xFF8FE3FF),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => ForgeScreen(
                                        library: _library!, save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.card_giftcard,
                              label: 'BOOSTERS',
                              color: const Color(0xFFC9A86A),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => BoosterScreen(
                                        library: _library!, save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.military_tech,
                              label: 'ARENA',
                              color: AppTheme.danger,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => ArenaScreen(
                                        library: _library!, save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.emoji_events,
                              label: 'AWARDS',
                              color: const Color(0xFFE3B341),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AchievementsScreen(save: _save!)),
                              ),
                            ),
                            _tile(
                              icon: Icons.school,
                              label: 'HOW TO PLAY',
                              color: DominionStyle.of(Dominion.dawn).glow,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const TutorialScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Set 1: The Sundering — PvE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0x779A97A8), fontSize: 10)),
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
                gradient: RadialGradient(colors: [
                  color.withValues(alpha: 0.45),
                  Colors.transparent
                ]),
                border: Border.all(color: color.withValues(alpha: 0.9), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontSize: 19,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill,
                color: color.withValues(alpha: 0.85), size: 30),
          ],
        ),
      ),
    );
  }

  /// Compact icon tile for the secondary actions grid.
  Widget _tile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
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
                      gradient: RadialGradient(colors: [
                        color.withValues(alpha: 0.35),
                        Colors.transparent
                      ]),
                      border:
                          Border.all(color: color.withValues(alpha: 0.8)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 9),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
