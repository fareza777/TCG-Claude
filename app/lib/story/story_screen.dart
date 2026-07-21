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
                  builder: (_) => ChapterPlayerScreen(
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
