import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../duel/duel_controller.dart';
import '../duel/duel_screen.dart';
import '../duel/scenario.dart';
import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'story_data.dart';

/// Plays a chapter stage-by-stage: narrative dialogue and scenario battles.
class ChapterPlayerScreen extends StatefulWidget {
  final StoryChapter chapter;
  final CardLibrary library;
  final SaveService save;

  const ChapterPlayerScreen({
    super.key,
    required this.chapter,
    required this.library,
    required this.save,
  });

  @override
  State<ChapterPlayerScreen> createState() => _ChapterPlayerScreenState();
}

class _ChapterPlayerScreenState extends State<ChapterPlayerScreen> {
  late int _stage;

  StoryChapter get ch => widget.chapter;
  StoryStage get current => ch.stages[_stage];

  @override
  void initState() {
    super.initState();
    _stage = widget.save.stageOf(ch.id).clamp(0, ch.stages.length - 1);
  }

  Future<void> _advance() async {
    if (_stage < ch.stages.length - 1) {
      setState(() => _stage++);
      await widget.save.setChapterStage(ch.id, _stage);
    } else {
      final bonus = await widget.save.completeChapter(ch.id);
      if (bonus > 0) AudioManager.instance.reward();
      if (mounted) {
        if (bonus > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chapter complete! +$bonus gold'),
            duration: const Duration(seconds: 2),
          ));
        }
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = current;
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
          child: stage.beat != null
              ? _BeatView(
                  key: ValueKey('beat$_stage'),
                  beat: stage.beat!,
                  chapter: ch,
                  stageIndex: _stage,
                  onDone: _advance,
                  onExit: () => Navigator.of(context).pop(),
                )
              : _BattleIntro(
                  key: ValueKey('battle$_stage'),
                  battle: stage.battle!,
                  chapter: ch,
                  library: widget.library,
                  save: widget.save,
                  stageIndex: _stage,
                  onVictory: _advance,
                  onExit: () => Navigator.of(context).pop(),
                ),
        ),
      ),
    );
  }
}

// ── narrative dialogue view ────────────────────────────────────────────────
class _BeatView extends StatefulWidget {
  final StoryBeat beat;
  final StoryChapter chapter;
  final int stageIndex;
  final VoidCallback onDone;
  final VoidCallback onExit;

  const _BeatView({
    super.key,
    required this.beat,
    required this.chapter,
    required this.stageIndex,
    required this.onDone,
    required this.onExit,
  });

  @override
  State<_BeatView> createState() => _BeatViewState();
}

class _BeatViewState extends State<_BeatView> {
  int _line = 0;

  void _next() {
    AudioManager.instance.tap();
    if (_line < widget.beat.dialogue.length - 1) {
      setState(() => _line++);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.beat.dialogue[_line];
    final narration = line.speaker.isEmpty;
    return GestureDetector(
      onTap: _next,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _topBar(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/art/${widget.beat.artAsset}.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: AppTheme.panel)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Text(widget.beat.title,
                      style: const TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10)
                          ])),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _dialogueBox(line, narration),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
          ),
          Expanded(
            child: Text(widget.chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ),
          Text('${widget.stageIndex + 1}/${widget.chapter.stages.length}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dialogueBox(DialogueLine line, bool narration) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: narration
                ? AppTheme.panelBorder
                : const Color(0xFFC9A86A).withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!narration)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line.speaker.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFFE6CE96),
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800)),
            ),
          Text(line.text,
              style: TextStyle(
                  fontFamily: 'EBGaramond',
                  color: narration
                      ? AppTheme.textMuted
                      : AppTheme.textPrimary,
                  fontStyle:
                      narration ? FontStyle.italic : FontStyle.normal,
                  fontSize: 16,
                  height: 1.45)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                _line < widget.beat.dialogue.length - 1
                    ? 'tap to continue  ▸'
                    : 'tap to proceed  ▸▸',
                style: const TextStyle(
                    color: Color(0x88C9A86A), fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── battle intro + launch ──────────────────────────────────────────────────
class _BattleIntro extends StatefulWidget {
  final StoryBattle battle;
  final StoryChapter chapter;
  final CardLibrary library;
  final SaveService save;
  final int stageIndex;
  final VoidCallback onVictory;
  final VoidCallback onExit;

  const _BattleIntro({
    super.key,
    required this.battle,
    required this.chapter,
    required this.library,
    required this.save,
    required this.stageIndex,
    required this.onVictory,
    required this.onExit,
  });

  @override
  State<_BattleIntro> createState() => _BattleIntroState();
}

class _BattleIntroState extends State<_BattleIntro> {
  int _preLine = 0;

  StoryBattle get b => widget.battle;

  bool get _preDone => _preLine >= b.preBattle.length;

  void _tapPre() {
    AudioManager.instance.tap();
    setState(() => _preLine++);
  }

  Future<void> _fight() async {
    AudioManager.instance.attack();
    final scenario = BattleScenario(
      playerHealth: b.playerHealth,
      enemyHealth: b.enemyHealth,
      enemyBoard: [for (final id in b.enemyBoardIds) widget.library.card(id)],
      playerBoard: [for (final id in b.playerBoardIds) widget.library.card(id)],
      objective: b.objective,
      specialRules: b.specialRules,
    );
    final controller = DuelController(
      playerDeck: widget.library.buildStarterDeck(widget.chapter.playerDominion),
      enemyDeck: widget.library.buildStarterDeck(b.enemyDominion),
      scenario: scenario,
      aiTier: b.hardAi ? AiTier.strategist : AiTier.tactician,
    );
    final won = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          DuelScreen(controller: controller, enemyName: b.enemyName),
    ));
    if (!mounted) return;
    if (won == true) {
      final reward =
          await widget.save.rewardStoryBattle('${widget.chapter.id}:${widget.stageIndex}');
      await widget.save.trackQuest('story_win');
      AudioManager.instance.reward();
      await _showVictory(reward);
      widget.onVictory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Defeated. Steel yourself and try again.'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showVictory(int reward) async {
    if (b.victory.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VictoryDialog(lines: b.victory, reward: reward),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = DominionStyle.of(
        Dominion.values.byName(b.enemyDominion.toLowerCase()));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.close,
                      color: AppTheme.textMuted, size: 20)),
              Expanded(
                  child: Text(widget.chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12))),
              Text('${widget.stageIndex + 1}/${widget.chapter.stages.length}',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      style.glow.withValues(alpha: 0.4),
                      Colors.transparent
                    ]),
                    border: Border.all(color: style.glow, width: 2),
                  ),
                  child: Icon(style.icon, color: style.glow, size: 44),
                ),
                const SizedBox(height: 14),
                const Text('BATTLE',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 13,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(b.enemyName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cinzel',
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _objectiveCard(),
                const SizedBox(height: 14),
                if (b.preBattle.isNotEmpty) _preDialogue(),
                const SizedBox(height: 20),
                if (_preDone || b.preBattle.isEmpty)
                  GestureDetector(
                    onTap: _fight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 52, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.danger,
                          AppTheme.danger.withValues(alpha: 0.6)
                        ]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppTheme.danger.withValues(alpha: 0.45),
                              blurRadius: 20)
                        ],
                      ),
                      child: const Text('FIGHT',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w900)),
                    ),
                  )
                else
                  const Text('tap the dialogue to continue',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _objectiveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, size: 15, color: Color(0xFFE6CE96)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(b.objective,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (b.specialRules.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final rule in b.specialRules)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.bolt,
                          size: 13, color: Color(0xFFB48AD1)),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(rule,
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              height: 1.35)),
                    ),
                  ],
                ),
              ),
          ],
          if (b.playerHealth != 25 || b.enemyHealth != 25) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _hpPill('You', b.playerHealth, AppTheme.health),
                const SizedBox(width: 10),
                _hpPill('Enemy', b.enemyHealth,
                    DominionStyle.of(Dominion.pyre).glow),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _hpPill(String who, int hp, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text('$who  $hp HP',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _preDialogue() {
    final shown = b.preBattle.take(_preLine + 1).toList();
    return GestureDetector(
      onTap: _preDone ? null : _tapPre,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFC9A86A).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (line.speaker.isNotEmpty)
                      Text(line.speaker.toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFFE6CE96),
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800)),
                    Text(line.text,
                        style: TextStyle(
                            fontFamily: 'EBGaramond',
                            color: line.speaker.isEmpty
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontStyle: line.speaker.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontSize: 14,
                            height: 1.4)),
                  ],
                ),
              ),
            if (!_preDone)
              const Align(
                alignment: Alignment.centerRight,
                child: Text('tap to continue  ▸',
                    style: TextStyle(color: Color(0x88C9A86A), fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

class _VictoryDialog extends StatefulWidget {
  final List<DialogueLine> lines;
  final int reward;
  const _VictoryDialog({required this.lines, required this.reward});

  @override
  State<_VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<_VictoryDialog> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final line = widget.lines[_i];
    final last = _i >= widget.lines.length - 1;
    return Dialog(
      backgroundColor: AppTheme.panel,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VICTORY',
                style: TextStyle(
                    color: Color(0xFFE3B341),
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            if (line.speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line.speaker.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFFE6CE96),
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800)),
              ),
            Text(line.text,
                style: TextStyle(
                    fontFamily: 'EBGaramond',
                    color: line.speaker.isEmpty
                        ? AppTheme.textMuted
                        : AppTheme.textPrimary,
                    fontStyle: line.speaker.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    fontSize: 15,
                    height: 1.45)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Color(0xFFE3B341), size: 16),
                const SizedBox(width: 5),
                Text('+${widget.reward} gold',
                    style: const TextStyle(
                        color: Color(0xFFF0E4C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    AudioManager.instance.tap();
                    if (last) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _i++);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFC9A86A), Color(0xFF8A713A)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(last ? 'CONTINUE' : 'NEXT  ▸',
                        style: const TextStyle(
                            color: Color(0xFF1C1508),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
