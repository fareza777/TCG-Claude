import 'card_def.dart';
import 'enums.dart';

/// A concrete copy of a card in a game. Identified by [instanceId].
class CardInstance {
  final int instanceId;
  final CardDef def;
  final PlayerId owner;
  final bool exerted;
  final int damage;
  final int plusCounters;
  final bool summonedThisTurn;

  /// Temporary buff from combat tricks — cleared at end of turn.
  final int tempMight;
  final int tempGuard;

  /// Keywords granted this turn (e.g. by a trick), cleared at end of turn.
  final Set<Keyword> tempKeywords;

  const CardInstance({
    required this.instanceId,
    required this.def,
    required this.owner,
    this.exerted = false,
    this.damage = 0,
    this.plusCounters = 0,
    this.summonedThisTurn = false,
    this.tempMight = 0,
    this.tempGuard = 0,
    this.tempKeywords = const {},
  });

  int get might => (def.might ?? 0) + plusCounters + tempMight;
  int get guard => (def.guard ?? 0) + plusCounters + tempGuard;
  Set<Keyword> get keywords =>
      tempKeywords.isEmpty ? def.keywords : {...def.keywords, ...tempKeywords};
  bool get isDead => def.type == CardType.unit && damage >= guard;
  bool get canAttack =>
      def.type == CardType.unit &&
      !exerted &&
      (!summonedThisTurn || keywords.contains(Keyword.rush));

  CardInstance copyWith({
    bool? exerted,
    int? damage,
    int? plusCounters,
    bool? summonedThisTurn,
    int? tempMight,
    int? tempGuard,
    Set<Keyword>? tempKeywords,
  }) =>
      CardInstance(
        instanceId: instanceId,
        def: def,
        owner: owner,
        exerted: exerted ?? this.exerted,
        damage: damage ?? this.damage,
        plusCounters: plusCounters ?? this.plusCounters,
        summonedThisTurn: summonedThisTurn ?? this.summonedThisTurn,
        tempMight: tempMight ?? this.tempMight,
        tempGuard: tempGuard ?? this.tempGuard,
        tempKeywords: tempKeywords ?? this.tempKeywords,
      );
}

/// Immutable per-player state.
class PlayerState {
  final PlayerId id;
  final int health;
  final List<CardInstance> deck;
  final List<CardInstance> hand;
  final List<CardInstance> arena;
  final List<CardInstance> ruins;
  final List<CardInstance> voidZone;
  final Map<Dominion, int> aetherPool;
  final bool playedWellspringThisTurn;
  final bool usedAttuneThisTurn;

  const PlayerState({
    required this.id,
    this.health = 25,
    this.deck = const [],
    this.hand = const [],
    this.arena = const [],
    this.ruins = const [],
    this.voidZone = const [],
    this.aetherPool = const {},
    this.playedWellspringThisTurn = false,
    this.usedAttuneThisTurn = false,
  });

  int get totalAether => aetherPool.values.fold(0, (a, b) => a + b);

  PlayerState copyWith({
    int? health,
    List<CardInstance>? deck,
    List<CardInstance>? hand,
    List<CardInstance>? arena,
    List<CardInstance>? ruins,
    List<CardInstance>? voidZone,
    Map<Dominion, int>? aetherPool,
    bool? playedWellspringThisTurn,
    bool? usedAttuneThisTurn,
  }) =>
      PlayerState(
        id: id,
        health: health ?? this.health,
        deck: deck ?? this.deck,
        hand: hand ?? this.hand,
        arena: arena ?? this.arena,
        ruins: ruins ?? this.ruins,
        voidZone: voidZone ?? this.voidZone,
        aetherPool: aetherPool ?? this.aetherPool,
        playedWellspringThisTurn:
            playedWellspringThisTurn ?? this.playedWellspringThisTurn,
        usedAttuneThisTurn: usedAttuneThisTurn ?? this.usedAttuneThisTurn,
      );
}

/// One pending spell/ability on the Chain (resolved LIFO).
class ChainItem {
  final CardInstance source;
  final PlayerId controller;
  final Map<String, dynamic> triggerBlock;
  final List<Object> chosenTargets; // EffectTarget list (kept untyped here)
  final bool uncounterable;
  final bool countered;

  const ChainItem({
    required this.source,
    required this.controller,
    required this.triggerBlock,
    this.chosenTargets = const [],
    this.uncounterable = false,
    this.countered = false,
  });

  ChainItem copyWith({bool? countered}) => ChainItem(
        source: source,
        controller: controller,
        triggerBlock: triggerBlock,
        chosenTargets: chosenTargets,
        uncounterable: uncounterable,
        countered: countered ?? this.countered,
      );
}

/// Root immutable game state. Every action produces a new GameState.
class GameState {
  final PlayerState p1;
  final PlayerState p2;
  final PlayerId activePlayer;
  final Phase phase;
  final int turnNumber;
  final int nextInstanceId;
  final int rngSeed;
  final PlayerId? winner;
  final List<ChainItem> chain;
  final PlayerId firstPlayer;

  const GameState({
    required this.p1,
    required this.p2,
    this.activePlayer = PlayerId.p1,
    this.phase = Phase.refresh,
    this.turnNumber = 1,
    this.nextInstanceId = 1,
    required this.rngSeed,
    this.winner,
    this.chain = const [],
    this.firstPlayer = PlayerId.p1,
  });

  PlayerState player(PlayerId id) => id == PlayerId.p1 ? p1 : p2;

  GameState withPlayer(PlayerState updated) => copyWith(
        p1: updated.id == PlayerId.p1 ? updated : null,
        p2: updated.id == PlayerId.p2 ? updated : null,
      );

  GameState copyWith({
    PlayerState? p1,
    PlayerState? p2,
    PlayerId? activePlayer,
    Phase? phase,
    int? turnNumber,
    int? nextInstanceId,
    PlayerId? winner,
    List<ChainItem>? chain,
  }) =>
      GameState(
        p1: p1 ?? this.p1,
        p2: p2 ?? this.p2,
        activePlayer: activePlayer ?? this.activePlayer,
        phase: phase ?? this.phase,
        turnNumber: turnNumber ?? this.turnNumber,
        nextInstanceId: nextInstanceId ?? this.nextInstanceId,
        rngSeed: rngSeed,
        winner: winner ?? this.winner,
        chain: chain ?? this.chain,
        firstPlayer: firstPlayer,
      );
}
