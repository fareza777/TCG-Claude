import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

/// The AI must take a win when it has one.
///
/// The tactician used to hold back any attacker that "loses a trade", which
/// meant a boss on the brink of victory would keep its units home and lose the
/// game it had already won. Nothing reads as more broken to a player.
CardDef unit(
  String id, {
  required int might,
  required int guard,
  Set<Keyword> keywords = const {},
}) =>
    CardDef(
      id: id,
      name: id,
      dominions: const [Dominion.pyre],
      type: CardType.unit,
      might: might,
      guard: guard,
      keywords: keywords,
    );

CardInstance onBoard(int id, CardDef def, PlayerId owner) =>
    CardInstance(instanceId: id, def: def, owner: owner);

void main() {
  /// Attacker that trades badly — 3 might into a 4-guard wall — but which
  /// together with its friend is exactly enough to finish the opponent.
  GameState lethalBoard({required int enemyHealth, List<CardInstance> blockers = const []}) {
    return GameState(
      p1: PlayerState(
        id: PlayerId.p1,
        arena: [
          onBoard(1, unit('Swinger', might: 3, guard: 1), PlayerId.p1),
          onBoard(2, unit('Second', might: 3, guard: 1), PlayerId.p1),
        ],
      ),
      p2: PlayerState(
        id: PlayerId.p2,
        health: enemyHealth,
        arena: blockers,
      ),
      rngSeed: 0,
      phase: Phase.combat,
    );
  }

  for (final tier in [AiTier.tactician, AiTier.strategist]) {
    test('${tier.name} swings everything when that is lethal', () {
      // A 4-guard wall makes both attacks losing trades in isolation.
      final wall = onBoard(9, unit('Wall', might: 1, guard: 4), PlayerId.p2);
      final s = lethalBoard(enemyHealth: 5, blockers: [wall]);
      final ai = AiPlayer(tier: tier);

      final attackers = ai.chooseAttackers(s, PlayerId.p1);
      expect(attackers, hasLength(2),
          reason: 'one blocker cannot stop both; 3 damage gets through and '
              'the opponent is on 5 — declining this is declining the game');
    });

    test('${tier.name} does not swing into a wall when it is not lethal', () {
      final wall = onBoard(9, unit('Wall', might: 4, guard: 4), PlayerId.p2);
      final s = lethalBoard(enemyHealth: 30, blockers: [wall]);
      final ai = AiPlayer(tier: tier);

      expect(ai.chooseAttackers(s, PlayerId.p1), isNot(hasLength(2)),
          reason: 'with the opponent at 30 there is nothing to race for, so '
              'feeding both units to a 4/4 is just a loss');
    });
  }

  test('a flier counts as lethal past a ground board', () {
    // Soar can only be blocked by Soar or Intercept, so these two ground
    // blockers are irrelevant and the attack is unstoppable.
    final s = GameState(
      p1: PlayerState(
        id: PlayerId.p1,
        arena: [
          onBoard(1, unit('Flier', might: 4, guard: 1, keywords: {Keyword.soar}),
              PlayerId.p1),
        ],
      ),
      p2: PlayerState(
        id: PlayerId.p2,
        health: 4,
        arena: [
          onBoard(8, unit('Ground A', might: 5, guard: 5), PlayerId.p2),
          onBoard(9, unit('Ground B', might: 5, guard: 5), PlayerId.p2),
        ],
      ),
      rngSeed: 0,
      phase: Phase.combat,
    );

    expect(const AiPlayer(tier: AiTier.tactician)
        .chooseAttackers(s, PlayerId.p1), [1],
        reason: 'nothing on that board can block Soar');
  });

  test('keywords break the tie between units of the same size', () {
    // Deliberately not claiming a small flier beats a big vanilla — a 5/5 is
    // genuinely strong, and pretending otherwise would be balancing the test
    // rather than the AI. The claim is narrower and true: at equal stats, a
    // card that does something is worth more.
    final plain = unit('Plain', might: 3, guard: 3);
    final flier = unit('Flier', might: 3, guard: 3,
        keywords: {Keyword.soar, Keyword.leech});
    expect(AiPlayer.unitValue(flier), greaterThan(AiPlayer.unitValue(plain)));
  });

  test('a defensive keyword is not mistaken for a threat', () {
    // Bulwark units cannot attack at all, so they must not outrank a body
    // that can — the old cost sort had no way to know that.
    final wall = unit('Wall', might: 2, guard: 6, keywords: {Keyword.bulwark});
    final beater = unit('Beater', might: 5, guard: 3, keywords: {Keyword.rush});
    expect(AiPlayer.unitValue(beater), greaterThan(AiPlayer.unitValue(wall)));
  });
}
