import 'story_data.dart';

/// Intended bands describe a Tactician proxy, not guaranteed human win rates.
enum StoryDifficultyBand {
  onboarding(0.75, 0.90),
  ordinary(0.50, 0.75),
  challenge(0.40, 0.60);

  final double lower;
  final double upper;
  const StoryDifficultyBand(this.lower, this.upper);
}

StoryDifficultyBand storyDifficultyBand(String chapterId, int battleNumber) {
  if (chapterId.startsWith('ch')) {
    if (battleNumber <= 3) return StoryDifficultyBand.onboarding;
    return battleNumber >= 16
        ? StoryDifficultyBand.challenge
        : StoryDifficultyBand.ordinary;
  }
  final chapter = int.parse(chapterId.substring(3));
  return chapter >= 16 || (chapter >= 11 && battleNumber == 2)
      ? StoryDifficultyBand.challenge
      : StoryDifficultyBand.ordinary;
}

class StoryDifficultySetup {
  final int playerHealth;
  final int enemyHealth;
  final List<String> playerBoardIds;
  final bool playerFirst;
  const StoryDifficultySetup(
    this.playerHealth,
    this.enemyHealth,
    this.playerBoardIds,
    this.playerFirst,
  );
}

// Explicit, reviewable fixed setups. There is no runtime adaptation or
// dependence on player history, losses, collection, or save state.
const storyDifficultySetups = <String, StoryDifficultySetup>{
  'ch1.1': StoryDifficultySetup(20, 22, ['SF001-001', 'SF001-003'], false),
  'ch1.2': StoryDifficultySetup(30, 29, ['SF001-001'], false),
  'ch1.3': StoryDifficultySetup(20, 15, ['SF001-001'], false),
  'ch1.4': StoryDifficultySetup(25, 30, [], false),
  'ch1.5': StoryDifficultySetup(30, 34, [], false),
  'ch1.6': StoryDifficultySetup(25, 30, [], false),
  'ch1.7': StoryDifficultySetup(30, 34, [], false),
  'ch1.8': StoryDifficultySetup(25, 30, [], false),
  'ch1.9': StoryDifficultySetup(25, 30, [], false),
  'ch1.10': StoryDifficultySetup(25, 36, [], false),
  'ch1.11': StoryDifficultySetup(30, 34, [], false),
  'ch1.12': StoryDifficultySetup(25, 27, [], false),
  'ch1.13': StoryDifficultySetup(25, 25, [], false),
  'ch1.14': StoryDifficultySetup(35, 35, ['SF001-004'], true),
  'ch1.15': StoryDifficultySetup(30, 28, ['SF001-001', 'SF001-004'], true),
  'ch1.16': StoryDifficultySetup(25, 17, ['SF001-001'], true),
  'ch1.17': StoryDifficultySetup(35, 37, ['SF001-001', 'SF001-004'], true),
  'ch1.18': StoryDifficultySetup(25, 46, ['SF001-001', 'SF001-004'], false),
  'ch1.19': StoryDifficultySetup(25, 42, [
    'SF001-001',
    'SF001-002',
    'SF001-004',
  ], true),
  'ch1.20': StoryDifficultySetup(35, 21, ['SF001-001', 'SF001-001'], false),
  'ch2.1': StoryDifficultySetup(25, 32, ['SF001-021', 'SF001-023'], true),
  'ch2.2': StoryDifficultySetup(20, 24, ['SF001-021'], false),
  'ch2.3': StoryDifficultySetup(30, 13, ['SF001-021'], true),
  'ch2.4': StoryDifficultySetup(25, 14, [], true),
  'ch2.5': StoryDifficultySetup(25, 14, [], true),
  'ch2.6': StoryDifficultySetup(30, 16, [], false),
  'ch2.7': StoryDifficultySetup(30, 16, [], false),
  'ch2.8': StoryDifficultySetup(25, 14, [], true),
  'ch2.9': StoryDifficultySetup(20, 27, [], false),
  'ch2.10': StoryDifficultySetup(25, 33, [], false),
  'ch2.11': StoryDifficultySetup(25, 36, [], false),
  'ch2.12': StoryDifficultySetup(25, 14, [], true),
  'ch2.13': StoryDifficultySetup(25, 49, ['SF001-025'], true),
  'ch2.14': StoryDifficultySetup(20, 21, ['SF001-021', 'SF001-021'], true),
  'ch2.15': StoryDifficultySetup(20, 26, ['SF001-021', 'SF001-022'], true),
  'ch2.16': StoryDifficultySetup(25, 22, ['SF001-023', 'SF001-021'], false),
  'ch2.17': StoryDifficultySetup(20, 18, ['SF001-021', 'SF001-021'], true),
  'ch2.18': StoryDifficultySetup(25, 39, [
    'SF001-023',
    'SF001-021',
    'SF001-022',
  ], false),
  'ch2.19': StoryDifficultySetup(25, 27, [
    'SF001-021',
    'SF001-021',
    'SF001-022',
  ], false),
  'ch2.20': StoryDifficultySetup(25, 23, ['SF001-025'], false),
  'ch3.1': StoryDifficultySetup(30, 22, ['SF001-041', 'SF001-043'], true),
  'ch3.2': StoryDifficultySetup(25, 24, ['SF001-041'], false),
  'ch3.3': StoryDifficultySetup(30, 21, ['SF001-041'], true),
  'ch3.4': StoryDifficultySetup(20, 25, [], false),
  'ch3.5': StoryDifficultySetup(30, 37, [], false),
  'ch3.6': StoryDifficultySetup(20, 12, [], false),
  'ch3.7': StoryDifficultySetup(20, 12, [], false),
  'ch3.8': StoryDifficultySetup(20, 25, [], false),
  'ch3.9': StoryDifficultySetup(30, 37, [], false),
  'ch3.10': StoryDifficultySetup(20, 24, [], false),
  'ch3.11': StoryDifficultySetup(20, 24, [], false),
  'ch3.12': StoryDifficultySetup(20, 17, [], true),
  'ch3.13': StoryDifficultySetup(25, 45, [
    'SF001-041',
    'SF001-042',
    'SF001-044',
  ], false),
  'ch3.14': StoryDifficultySetup(30, 36, ['SF001-044'], true),
  'ch3.15': StoryDifficultySetup(35, 18, ['SF001-042', 'SF001-042'], false),
  'ch3.16': StoryDifficultySetup(25, 24, [
    'SF001-041',
    'SF001-041',
    'SF001-042',
  ], true),
  'ch3.17': StoryDifficultySetup(30, 30, ['SF001-041', 'SF001-044'], true),
  'ch3.18': StoryDifficultySetup(40, 31, ['SF001-043', 'SF001-044'], true),
  'ch3.19': StoryDifficultySetup(35, 37, [
    'SF001-041',
    'SF001-042',
    'SF001-044',
  ], true),
  'ch3.20': StoryDifficultySetup(35, 26, ['SF001-041', 'SF001-044'], false),
  'ch4.1': StoryDifficultySetup(20, 22, ['SF001-061', 'SF001-063'], false),
  'ch4.2': StoryDifficultySetup(30, 26, ['SF001-061'], false),
  'ch4.3': StoryDifficultySetup(30, 25, ['SF001-061'], false),
  'ch4.4': StoryDifficultySetup(25, 35, [], false),
  'ch4.5': StoryDifficultySetup(30, 25, [], false),
  'ch4.6': StoryDifficultySetup(25, 35, [], false),
  'ch4.7': StoryDifficultySetup(25, 26, [], false),
  'ch4.8': StoryDifficultySetup(30, 25, [], false),
  'ch4.9': StoryDifficultySetup(25, 35, [], false),
  'ch4.10': StoryDifficultySetup(20, 29, [], false),
  'ch4.11': StoryDifficultySetup(20, 29, [], false),
  'ch4.12': StoryDifficultySetup(30, 27, [], false),
  'ch4.13': StoryDifficultySetup(25, 39, ['SF001-061', 'SF001-062'], false),
  'ch4.14': StoryDifficultySetup(30, 43, ['SF001-061', 'SF001-064'], false),
  'ch4.15': StoryDifficultySetup(25, 25, [
    'SF001-061',
    'SF001-061',
    'SF001-062',
  ], false),
  'ch4.16': StoryDifficultySetup(20, 21, ['SF001-063', 'SF001-065'], true),
  'ch4.17': StoryDifficultySetup(30, 23, [
    'SF001-061',
    'SF001-062',
    'SF001-064',
  ], true),
  'ch4.18': StoryDifficultySetup(40, 34, ['SF001-063', 'SF001-065'], false),
  'ch4.19': StoryDifficultySetup(30, 19, [
    'SF001-061',
    'SF001-062',
    'SF001-064',
  ], false),
  'ch4.20': StoryDifficultySetup(40, 24, ['SF001-064'], false),
  'ch5.1': StoryDifficultySetup(20, 23, ['SF001-081', 'SF001-084'], true),
  'ch5.2': StoryDifficultySetup(25, 14, ['SF001-081'], true),
  'ch5.3': StoryDifficultySetup(25, 14, ['SF001-081'], true),
  'ch5.4': StoryDifficultySetup(25, 13, [], true),
  'ch5.5': StoryDifficultySetup(30, 32, [], false),
  'ch5.6': StoryDifficultySetup(25, 13, [], true),
  'ch5.7': StoryDifficultySetup(30, 16, [], true),
  'ch5.8': StoryDifficultySetup(30, 22, [], false),
  'ch5.9': StoryDifficultySetup(25, 13, [], true),
  'ch5.10': StoryDifficultySetup(30, 16, [], true),
  'ch5.11': StoryDifficultySetup(30, 16, [], true),
  'ch5.12': StoryDifficultySetup(30, 32, [], false),
  'ch5.13': StoryDifficultySetup(30, 45, ['SF001-082', 'SF001-082'], false),
  'ch5.14': StoryDifficultySetup(40, 46, ['SF001-081', 'SF001-082'], false),
  'ch5.15': StoryDifficultySetup(40, 35, [
    'SF001-081',
    'SF001-081',
    'SF001-082',
  ], false),
  'ch5.16': StoryDifficultySetup(35, 12, ['SF001-081'], true),
  'ch5.17': StoryDifficultySetup(40, 25, [
    'SF001-081',
    'SF001-082',
    'SF001-084',
  ], false),
  'ch5.18': StoryDifficultySetup(40, 28, ['SF001-081', 'SF001-084'], true),
  'ch5.19': StoryDifficultySetup(45, 22, ['SF001-081', 'SF001-081'], true),
  'ch5.20': StoryDifficultySetup(45, 38, [
    'SF001-084',
    'SF001-081',
    'SF001-082',
  ], false),
  'vow01.1': StoryDifficultySetup(35, 29, ['SF002-179'], true),
  'vow01.2': StoryDifficultySetup(30, 28, ['SF002-174'], false),
  'vow02.1': StoryDifficultySetup(25, 17, ['SF002-131'], false),
  'vow02.2': StoryDifficultySetup(35, 47, ['SF002-137'], true),
  'vow03.1': StoryDifficultySetup(30, 27, ['SF002-003'], false),
  'vow03.2': StoryDifficultySetup(25, 28, ['SF002-002'], true),
  'vow04.1': StoryDifficultySetup(30, 32, ['SF002-045', 'SF002-045'], true),
  'vow04.2': StoryDifficultySetup(35, 17, ['SF002-045'], true),
  'vow05.1': StoryDifficultySetup(25, 27, ['SF002-091'], false),
  'vow05.2': StoryDifficultySetup(25, 30, ['SF002-091'], true),
  'vow06.1': StoryDifficultySetup(30, 41, ['SF002-003', 'SF002-003'], false),
  'vow06.2': StoryDifficultySetup(25, 26, ['SF002-002', 'SF002-007'], true),
  'vow07.1': StoryDifficultySetup(30, 35, ['SF002-045'], true),
  'vow07.2': StoryDifficultySetup(30, 24, ['SF002-048'], false),
  'vow08.1': StoryDifficultySetup(25, 28, ['SF002-091'], false),
  'vow08.2': StoryDifficultySetup(35, 36, [], false),
  'vow09.1': StoryDifficultySetup(35, 43, ['SF002-134'], true),
  'vow09.2': StoryDifficultySetup(25, 36, ['SF002-136'], false),
  'vow10.1': StoryDifficultySetup(30, 26, ['SF002-179'], true),
  'vow10.2': StoryDifficultySetup(35, 23, ['SF002-176'], false),
  'vow11.1': StoryDifficultySetup(25, 34, ['SF002-133', 'SF002-133'], false),
  'vow11.2': StoryDifficultySetup(35, 22, [], false),
  'vow12.1': StoryDifficultySetup(35, 36, ['SF002-048'], false),
  'vow12.2': StoryDifficultySetup(35, 14, ['SF002-045'], true),
  'vow13.1': StoryDifficultySetup(35, 37, ['SF002-093'], true),
  'vow13.2': StoryDifficultySetup(35, 19, ['SF002-088', 'SF002-090'], false),
  'vow14.1': StoryDifficultySetup(35, 34, ['SF002-005'], false),
  'vow14.2': StoryDifficultySetup(30, 35, ['SF002-003', 'SF002-008'], true),
  'vow15.1': StoryDifficultySetup(30, 36, ['SF002-177'], true),
  'vow15.2': StoryDifficultySetup(30, 22, ['SF002-176', 'SF002-176'], true),
  'vow16.1': StoryDifficultySetup(30, 43, ['SF002-045', 'SF002-045'], true),
  'vow16.2': StoryDifficultySetup(35, 33, ['SF002-048'], false),
  'vow17.1': StoryDifficultySetup(35, 32, [], false),
  'vow17.2': StoryDifficultySetup(40, 23, [], true),
  'vow18.1': StoryDifficultySetup(30, 25, [], true),
  'vow18.2': StoryDifficultySetup(30, 33, ['SF002-133'], false),
  'vow19.1': StoryDifficultySetup(35, 30, ['SF002-174', 'SF002-174'], true),
  'vow19.2': StoryDifficultySetup(35, 28, [
    'SF002-174',
    'SF002-176',
    'SF002-179',
  ], true),
  'vow20.1': StoryDifficultySetup(40, 20, ['SF002-005'], true),
  'vow20.2': StoryDifficultySetup(40, 36, ['SF002-005'], false),
};

StoryChapter tuneStoryChapter(StoryChapter chapter) {
  var number = 0;
  return StoryChapter(
    id: chapter.id,
    title: chapter.title,
    subtitle: chapter.subtitle,
    playerDominion: chapter.playerDominion,
    stages: [
      for (final stage in chapter.stages)
        if (stage.battle case final battle?)
          StoryStage.fight(
            _tuneBattle(
              battle,
              storyDifficultySetups['${chapter.id}.${++number}'],
            ),
          )
        else
          stage,
    ],
  );
}

StoryBattle _tuneBattle(StoryBattle battle, StoryDifficultySetup? setup) {
  if (setup == null) return battle;
  final playerHealth = setup.playerHealth;
  final enemyHealth = setup.enemyHealth;
  final allies = setup.playerBoardIds;
  final enemies = battle.enemyBoardIds;
  const countWords = ['One', 'Two', 'Three'];
  return StoryBattle(
    enemyDominion: battle.enemyDominion,
    enemyName: battle.enemyName,
    deckSetCode: battle.deckSetCode,
    deckVariant: battle.deckVariant,
    objective: battle.objective,
    playerHealth: playerHealth,
    enemyHealth: enemyHealth,
    playerBoardIds: allies,
    enemyBoardIds: enemies,
    playerFirst: setup.playerFirst,
    hardAi: battle.hardAi,
    preBattle: battle.preBattle,
    victory: battle.victory,
    specialRules: [
      // Preserve authored narrative/objective rules, replacing only facts
      // about setup that would otherwise become stale after tuning.
      ...battle.specialRules.where((line) => !_describesSetup(line)),
      'The foe has $enemyHealth Health to your $playerHealth.',
      if (playerHealth != 25) 'You begin with $playerHealth Health.',
      if (allies.isEmpty)
        'You begin with an empty board.'
      else
        '${countWords[allies.length - 1]} of your allies '
            '${allies.length == 1 ? 'stands' : 'stand'} with you.',
      if (enemies.isEmpty)
        'The enemy begins with an empty board.'
      else
        'The enemy opens with ${enemies.length == 1 ? 'one creature' : '${enemies.length} creatures'} in play.',
      if (setup.playerFirst)
        'You take the first turn.'
      else
        'The foe takes the first turn. You draw an extra opening card.',
    ],
  );
}

bool _describesSetup(String line) =>
    RegExp(r'\d+ Health').hasMatch(line) ||
    line.contains('stand with you') ||
    line.contains('stands with you') ||
    line.startsWith('You begin with') ||
    line.startsWith('The enemy opens') ||
    line.startsWith('The enemy begins') ||
    line.startsWith('The foe takes the first turn') ||
    line == 'No help on either side.';
