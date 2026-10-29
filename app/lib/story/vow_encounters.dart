import 'package:shardfall_engine/shardfall_engine.dart';
import 'story_data.dart';

const _first = {
  'VERDANCE': 1,
  'PYRE': 44,
  'TIDE': 87,
  'DAWN': 130,
  'GLOOM': 173,
};
String _card(String dominion, int offset) =>
    'SF002-${(_first[dominion]! + offset).toString().padLeft(3, '0')}';

/// Loan decks use actual SF002 cards and a playable curve: 16 Wellsprings,
/// six kinds of units plus interaction, three copies of each non-resource.
/// The pledge and mending slots expose Vow and Renew through real play.
List<CardDef> storyDeck(
  CardLibrary library,
  String dominion, {
  String? setCode,
  int variant = 0,
}) {
  if (setCode == null) return library.buildStarterDeck(dominion);
  if (setCode != 'SF002') throw ArgumentError('Unknown story set: $setCode');
  const rosters = [
    [1, 3, 4, 6, 9, 11, 13, 14],
    [2, 3, 5, 7, 10, 12, 14, 17],
    [1, 3, 6, 8, 9, 11, 14, 18],
  ];
  return [
    for (var i = 0; i < 16; i++) library.card(_card(dominion, 0)),
    for (final offset in rosters[variant % rosters.length])
      for (var i = 0; i < 3; i++) library.card(_card(dominion, dominion == 'PYRE' && offset == 3 ? 8 : offset)),
  ];
}

/// Encounter modifiers are generated from the actual board, never narrative
/// promises of rules the duel does not implement. Every win remains a normal
/// duel victory; the location's story objective gives that duel its purpose.
StoryStage vowBattle({
  required int chapter,
  required int encounter,
  required String player,
  required String enemy,
  required String name,
  required String objective,
  required List<DialogueLine> pre,
  required List<DialogueLine> victory,
}) {
  final act = (chapter - 1) ~/ 5;
  final answeredBoard = encounter == 2 && act > 0;
  final needsSecond = ((chapter == 2 || chapter == 11) && encounter == 1) ||
      (chapter == 13 && encounter == 2);
  final allyIds = [_card(player, 4), if (needsSecond) _card(player, 3)];
  final enemyIds = [if (answeredBoard) _card(enemy, 3)];
  final playerHealth = chapter >= 16 || (chapter == 13 && encounter == 2) ? 35 : 30;
  final enemyHealth = 22 + act + (encounter == 2 ? 3 : 0);
  return StoryStage.fight(
    StoryBattle(
      enemyDominion: enemy,
      enemyName: name,
      objective: objective,
      deckSetCode: 'SF002',
      deckVariant: chapter + encounter,
      playerHealth: playerHealth,
      enemyHealth: enemyHealth,
      playerBoardIds: allyIds,
      enemyBoardIds: enemyIds,
      hardAi: encounter == 2 && chapter >= 11,
      playerFirst: false,
      specialRules: [
        'The foe has $enemyHealth Health to your $playerHealth.',
        'Both sides use The Five Vows loan decks; your collection is not required.',
        'You begin with ${allyIds.length} allied ${allyIds.length == 1 ? 'unit' : 'units'} in play.',
        if (answeredBoard)
          'The enemy opens with one creature in play.'
        else
          'The enemy begins with an empty board.',
        'The foe takes the first turn. You draw an extra opening card.',
        'Win by reducing the enemy to 0 Health.',
      ],
      preBattle: pre,
      victory: victory,
    ),
  );
}
