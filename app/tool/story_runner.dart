// The part of the story simulator that plays one battle, shared by the report
// (story_sim.dart) and the calibrator (story_calibrate.dart).
//
// A battle is built exactly as chapter_player builds it -- the chapter's
// starter deck against the foe's, the same scenario applied, the Strategist
// for boss fights and the Tactician otherwise -- with an AI seated as the
// player. The AI contains no randomness, so the only variation between games
// is the seed's shuffle and results are reproducible.
import 'package:shardfall/duel/scenario.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

const _turnGuard = 300;

/// Every part of a battle that a change can touch.
class Setup {
  final int playerHealth;
  final int enemyHealth;
  final List<String> enemyBoard;
  final List<String> playerBoard;

  /// The player takes the second turn (and so the extra opening card).
  final bool playerSecond;

  const Setup({
    required this.playerHealth,
    required this.enemyHealth,
    required this.enemyBoard,
    required this.playerBoard,
    this.playerSecond = false,
  });

  factory Setup.of(StoryBattle b) => Setup(
        playerHealth: b.playerHealth,
        enemyHealth: b.enemyHealth,
        enemyBoard: [...b.enemyBoardIds],
        playerBoard: [...b.playerBoardIds],
        playerSecond: !b.playerFirst,
      );

  Setup copyWith({
    int? playerHealth,
    int? enemyHealth,
    List<String>? enemyBoard,
    List<String>? playerBoard,
    bool? playerSecond,
  }) =>
      Setup(
        playerHealth: playerHealth ?? this.playerHealth,
        enemyHealth: enemyHealth ?? this.enemyHealth,
        enemyBoard: enemyBoard ?? this.enemyBoard,
        playerBoard: playerBoard ?? this.playerBoard,
        playerSecond: playerSecond ?? this.playerSecond,
      );
}

/// True if the player won, false if the foe did, null if neither within the
/// turn guard (a stall, counted as no win).
bool? playBattle({
  required CardLibrary library,
  required StoryChapter chapter,
  required StoryBattle battle,
  required Setup setup,
  required AiTier playerSkill,
  required int seed,
}) {
  const human = PlayerId.p1;
  const enemy = PlayerId.p2;

  final scenario = BattleScenario(
    playerHealth: setup.playerHealth,
    enemyHealth: setup.enemyHealth,
    enemyBoard: [for (final id in setup.enemyBoard) library.card(id)],
    playerBoard: [for (final id in setup.playerBoard) library.card(id)],
  );

  var s = Game.create(
    deckP1: library.buildStarterDeck(chapter.playerDominion),
    deckP2: library.buildStarterDeck(battle.enemyDominion),
    seed: seed,
    firstPlayer: setup.playerSecond ? PlayerId.p2 : PlayerId.p1,
  );
  if (scenario.isModified) {
    s = scenario.apply(s, human: human, enemy: enemy);
  }

  final player = AiPlayer(tier: playerSkill);
  final foe =
      AiPlayer(tier: battle.hardAi ? AiTier.strategist : AiTier.tactician);

  var guard = 0;
  while (s.winner == null && guard++ < _turnGuard) {
    final mine = s.activePlayer == human;
    s = (mine ? player : foe)
        .playTurn(s, s.activePlayer, defenderAi: mine ? foe : player);
    if (s.winner != null) break;
    s = Game.nextPhase(s);
  }
  if (s.winner == null) return null;
  return s.winner == human;
}

/// Fraction of [games] seeds the player wins. A calibration and its check
/// should use different [seedBase]s, or a change that passed by luck passes
/// the check by the same luck.
double winRate({
  required CardLibrary library,
  required StoryChapter chapter,
  required StoryBattle battle,
  required Setup setup,
  required AiTier playerSkill,
  required int games,
  int seedBase = 1000,
}) {
  var wins = 0;
  for (var g = 0; g < games; g++) {
    final result = playBattle(
      library: library,
      chapter: chapter,
      battle: battle,
      setup: setup,
      playerSkill: playerSkill,
      seed: seedBase + g * 37,
    );
    if (result == true) wins++;
  }
  return wins / games;
}
