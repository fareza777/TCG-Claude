// Story campaign — dialogue-driven, RPG-style, with battle scenarios that
// carry objectives, special rules, and pre-set board states.
// Each beat has dedicated storyboard art at assets/art/STORY-<id>.webp.
//
// Chapters live in chapters/ once they grow past a few battles — twenty fights
// each would otherwise put every chapter in one unreadable file.

import 'chapters/chapter_one.dart';
import 'chapters/chapter_two.dart';
import 'chapters/chapter_three.dart';
import 'chapters/chapter_four.dart';
import 'chapters/chapter_five.dart';
import 'chapters/vows_act_1.dart';
import 'chapters/vows_act_2.dart';
import 'chapters/vows_act_3.dart';
import 'chapters/vows_act_4.dart';
import 'story_difficulty.dart';

class DialogueLine {
  final String speaker; // '' for narration
  final String text;
  const DialogueLine(this.speaker, this.text);
  const DialogueLine.narrate(this.text) : speaker = '';
}

class StoryBeat {
  final String artAsset;
  final String title;
  final List<DialogueLine> dialogue;
  const StoryBeat({
    required this.artAsset,
    required this.title,
    required this.dialogue,
  });
}

/// A battle with RPG modifiers. Card ids are resolved to decks/boards by the
/// story screen against the loaded [CardLibrary].
class StoryBattle {
  final String enemyDominion; // starter deck key for the foe
  final String enemyName;

  /// Null keeps the original starter decks. SF002 uses the expansion's
  /// curated loan decks, independently of the player's collection.
  final String? deckSetCode;
  final int deckVariant;
  final String objective;
  final List<String> specialRules;
  final int playerHealth;
  final int enemyHealth;
  final List<String> enemyBoardIds;
  final List<String> playerBoardIds;
  final List<DialogueLine> preBattle;
  final List<DialogueLine> victory;

  /// Boss fights use the smarter Strategist AI.
  final bool hardAi;

  /// Whether the player takes the first turn. Almost every fight leaves this
  /// true; the few that do not hand the player the second turn, which is worth
  /// an extra opening card and a look at what the foe does first. Measured with
  /// the story simulator, moving first is the weaker seat in this game.
  final bool playerFirst;

  const StoryBattle({
    required this.enemyDominion,
    required this.enemyName,
    this.deckSetCode,
    this.deckVariant = 0,
    this.objective = 'Reduce the enemy to 0 Health.',
    this.specialRules = const [],
    this.playerHealth = 25,
    this.enemyHealth = 25,
    this.enemyBoardIds = const [],
    this.playerBoardIds = const [],
    this.preBattle = const [],
    this.victory = const [],
    this.hardAi = false,
    this.playerFirst = true,
  });
}

class StoryStage {
  final StoryBeat? beat;
  final StoryBattle? battle;
  const StoryStage.read(StoryBeat this.beat) : battle = null;
  const StoryStage.fight(StoryBattle this.battle) : beat = null;
}

class StoryChapter {
  final String id;
  final String title;
  final String subtitle;
  final String playerDominion;
  final List<StoryStage> stages;
  const StoryChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.playerDominion,
    required this.stages,
  });

  int get battleCount => stages.where((s) => s.battle != null).length;
}

/// Original authored chapters are retained unchanged for audit comparison.
final authoredStoryChapters = <StoryChapter>[
  chapterOne,
  chapterTwo,
  chapterThree,
  chapterFour,
  chapterFive,
  vow01,
  vow02,
  vow03,
  vow04,
  vow05,
  vow06,
  vow07,
  vow08,
  vow09,
  vow10,
  vow11,
  vow12,
  vow13,
  vow14,
  vow15,
  vow16,
  vow17,
  vow18,
  vow19,
  vow20,
];

/// Runtime encounters use explicit fixed setups; the authored dialogue and
/// stage positions remain the source of truth for narrative and voice IDs.
final storyChapters = [
  for (final chapter in authoredStoryChapters) tuneStoryChapter(chapter),
];
