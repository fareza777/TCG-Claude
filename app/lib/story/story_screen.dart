import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'chapter_player.dart';
import 'story_data.dart';

/// Chapter select. Chapters unlock in sequence.
class StoryScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;

  const StoryScreen({super.key, required this.library, required this.save});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  bool _unlocked(int index) {
    if (index == 0) return true;
    return widget.save.chapterDone(storyChapters[index - 1].id);
  }

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
                padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('Story Campaign',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: storyChapters.length,
                  itemBuilder: (_, i) =>
                      _chapterCard(storyChapters[i], i, _unlocked(i)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterCard(StoryChapter ch, int index, bool unlocked) {
    final done = widget.save.chapterDone(ch.id);
    final stage = widget.save.stageOf(ch.id);
    final dom = Dominion.values.byName(ch.playerDominion.toLowerCase());
    final style = DominionStyle.of(dom);
    final progress = (stage / ch.stages.length).clamp(0.0, 1.0);

    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: GestureDetector(
        onTap: unlocked
            ? () async {
                AudioManager.instance.tap();
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ChapterMapScreen(
                      chapter: ch,
                      library: widget.library,
                      save: widget.save),
                ));
                setState(() {});
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.frame[1], style.frame[2]],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: unlocked
                    ? style.glow.withValues(alpha: 0.6)
                    : AppTheme.panelBorder),
          ),
          child: Row(
            children: [
              Icon(unlocked ? style.icon : Icons.lock,
                  color: unlocked ? style.glow : AppTheme.textMuted,
                  size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Text(ch.subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11)),
                    const SizedBox(height: 8),
                    if (unlocked)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: done ? 1 : progress,
                          minHeight: 5,
                          backgroundColor: Colors.black26,
                          valueColor: AlwaysStoppedAnimation(style.glow),
                        ),
                      )
                    else
                      Text(
                          'Complete ${storyChapters[index - 1].title.split('—').first.trim()} to unlock',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              if (done)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle,
                      color: Color(0xFF7FE0A8), size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stage-select map for a chapter: scroll through every beat and battle,
/// continue the story, or replay any stage you have already reached.
class ChapterMapScreen extends StatefulWidget {
  final StoryChapter chapter;
  final CardLibrary library;
  final SaveService save;

  const ChapterMapScreen({
    super.key,
    required this.chapter,
    required this.library,
    required this.save,
  });

  @override
  State<ChapterMapScreen> createState() => _ChapterMapScreenState();
}

class _ChapterMapScreenState extends State<ChapterMapScreen> {
  StoryChapter get ch => widget.chapter;

  /// Furthest stage the player may enter: the whole chapter once cleared,
  /// otherwise everything up to their saved progress.
  int get _furthest => widget.save.chapterDone(ch.id)
      ? ch.stages.length - 1
      : widget.save.stageOf(ch.id).clamp(0, ch.stages.length - 1);

  Future<void> _play({required int stage, required bool freePlay}) async {
    AudioManager.instance.tap();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChapterPlayerScreen(
        chapter: ch,
        library: widget.library,
        save: widget.save,
        startStage: stage,
        freePlay: freePlay,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dom = Dominion.values.byName(ch.playerDominion.toLowerCase());
    final style = DominionStyle.of(dom);
    final furthest = _furthest;
    final resume =
        widget.save.stageOf(ch.id).clamp(0, ch.stages.length - 1);
    final done = widget.save.chapterDone(ch.id);
    var battleNo = 0;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ch.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          Text('${ch.battleCount} battles · ${ch.subtitle}',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Continue / Start button.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: GestureDetector(
                  onTap: () => _play(stage: resume, freePlay: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        style.glow.withValues(alpha: 0.85),
                        style.frame[1],
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: style.glow.withValues(alpha: 0.4),
                            blurRadius: 16),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(done ? Icons.replay : Icons.play_arrow,
                            color: Colors.black.withValues(alpha: 0.8),
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                            done
                                ? 'REPLAY FROM START'
                                : resume == 0
                                    ? 'BEGIN CHAPTER'
                                    : 'CONTINUE STORY',
                            style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.85),
                                fontSize: 14,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: ch.stages.length,
                  itemBuilder: (_, i) {
                    final stage = ch.stages[i];
                    final isBattle = stage.battle != null;
                    if (isBattle) battleNo++;
                    final unlocked = i <= furthest;
                    final cleared = i < resume || done;
                    return _stageRow(
                      index: i,
                      stage: stage,
                      isBattle: isBattle,
                      battleNo: isBattle ? battleNo : null,
                      unlocked: unlocked,
                      cleared: cleared,
                      isCurrent: i == resume && !done,
                      style: style,
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

  Widget _stageRow({
    required int index,
    required StoryStage stage,
    required bool isBattle,
    required int? battleNo,
    required bool unlocked,
    required bool cleared,
    required bool isCurrent,
    required DominionStyle style,
  }) {
    final title = isBattle ? stage.battle!.enemyName : stage.beat!.title;
    final subtitle = isBattle
        ? (battleNo != null ? 'Battle $battleNo' : 'Battle')
        : 'Story';
    final color = isBattle ? AppTheme.danger : style.glow;

    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: GestureDetector(
        onTap: unlocked
            // Replaying an already-cleared stage is free-play; the current
            // (not-yet-done) stage continues the story normally.
            ? () => _play(stage: index, freePlay: cleared)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isCurrent ? 0.5 : 0.28),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: isCurrent
                    ? color
                    : unlocked
                        ? AppTheme.panelBorder
                        : AppTheme.panelBorder.withValues(alpha: 0.4),
                width: isCurrent ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Icon(
                    unlocked
                        ? (isBattle
                            ? Icons.local_fire_department
                            : Icons.menu_book)
                        : Icons.lock,
                    size: 16,
                    color: unlocked ? color : AppTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle.toUpperCase(),
                        style: TextStyle(
                            color: color.withValues(alpha: 0.9),
                            fontSize: 9.5,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (cleared)
                const Icon(Icons.check_circle,
                    color: Color(0xFF7FE0A8), size: 18)
              else if (isCurrent)
                Icon(Icons.play_circle_fill, color: color, size: 20)
              else if (unlocked)
                Icon(Icons.chevron_right,
                    color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
