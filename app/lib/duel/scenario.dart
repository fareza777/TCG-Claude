import 'package:shardfall_engine/shardfall_engine.dart';

/// RPG-style battle modifiers applied on top of a fresh duel. Lets story
/// battles feel distinct: bosses that open with a board, uphill fights at
/// reduced Health, or handicaps that make an "easy" foe a tutorial.
class BattleScenario {
  final int playerHealth;
  final int enemyHealth;

  /// Cards pre-deployed to each side's Arena at the start of the battle.
  final List<CardDef> enemyBoard;
  final List<CardDef> playerBoard;

  /// One-line objective + any special rules, shown on the battle intro card.
  final String objective;
  final List<String> specialRules;

  const BattleScenario({
    this.playerHealth = 25,
    this.enemyHealth = 25,
    this.enemyBoard = const [],
    this.playerBoard = const [],
    this.objective = 'Reduce the enemy to 0 Health.',
    this.specialRules = const [],
  });

  bool get isModified =>
      playerHealth != 25 ||
      enemyHealth != 25 ||
      enemyBoard.isNotEmpty ||
      playerBoard.isNotEmpty;

  /// Apply this scenario to a freshly created [GameState].
  GameState apply(GameState s, {required PlayerId human, required PlayerId enemy}) {
    var nextId = s.nextInstanceId;
    List<CardInstance> place(List<CardDef> defs, PlayerId owner) => [
          for (final d in defs)
            CardInstance(instanceId: nextId++, def: d, owner: owner),
        ];
    final enemyUnits = place(enemyBoard, enemy);
    final playerUnits = place(playerBoard, human);

    final hp = s.player(human).copyWith(
      health: playerHealth,
      arena: [...s.player(human).arena, ...playerUnits],
    );
    final ep = s.player(enemy).copyWith(
      health: enemyHealth,
      arena: [...s.player(enemy).arena, ...enemyUnits],
    );
    return s.withPlayer(hp).withPlayer(ep).copyWith(nextInstanceId: nextId);
  }
}
