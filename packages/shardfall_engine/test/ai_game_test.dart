import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef unitDef(String id, int cost, int might, int guard) => CardDef(
      id: id,
      name: 'Unit $id',
      dominions: const [Dominion.pyre],
      type: CardType.unit,
      costGeneric: cost > 0 ? cost - 1 : 0,
      costDominion: cost > 0 ? const {Dominion.pyre: 1} : const {},
      might: might,
      guard: guard,
    );

CardDef wellspringDef(String id) => CardDef(
      id: id,
      name: 'Pyre Wellspring',
      dominions: const [Dominion.pyre],
      type: CardType.wellspring,
    );

List<CardDef> aggroDeck() => [
      for (var i = 0; i < 16; i++) wellspringDef('WS$i'),
      for (var i = 0; i < 8; i++) unitDef('S$i', 1, 2, 1),
      for (var i = 0; i < 8; i++) unitDef('M$i', 2, 2, 2),
      for (var i = 0; i < 8; i++) unitDef('L$i', 4, 4, 4),
    ];

void main() {
  test('AI vs AI: full game completes with a winner, deterministically', () {
    GameState run(int seed) {
      var s = Game.create(deckP1: aggroDeck(), deckP2: aggroDeck(), seed: seed);
      const ai = AiPlayer(tier: AiTier.greedy);
      var guard = 0;
      while (s.winner == null && guard < 200) {
        s = ai.playTurn(s, s.activePlayer);
        if (s.winner != null) break;
        s = Game.nextPhase(s); // end -> pass turn
        guard++;
      }
      return s;
    }

    final a = run(1234);
    expect(a.winner, isNotNull, reason: 'game must end');

    final b = run(1234);
    expect(b.winner, a.winner, reason: 'same seed, same outcome');
    expect(b.turnNumber, a.turnNumber, reason: 'bit-identical replay');
  });

  test('AI never aims a unit-only damage spell at the player', () {
    const unitOnly = CardDef(
      id: 'WITHER',
      name: 'Wither',
      dominions: [Dominion.gloom],
      type: CardType.rite,
      text: 'Deal 3 damage to target Unit.',
      effects: [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {'op': 'DEAL_DAMAGE', 'amount': 3, 'target': {'select': 'CHOOSE'}}
          ],
        }
      ],
    );
    const anyTarget = CardDef(
      id: 'BOLT',
      name: 'Cinder Bolt',
      dominions: [Dominion.pyre],
      type: CardType.rite,
      text: 'Deal 2 damage to any target.',
      effects: [
        {
          'trigger': 'ON_CAST',
          'effects': [
            {'op': 'DEAL_DAMAGE', 'amount': 2, 'target': {'select': 'CHOOSE'}}
          ],
        }
      ],
    );
    const ai = AiPlayer();
    // Opponent has no units and low health → tempting to hit the face.
    final s = GameState(
      p1: const PlayerState(id: PlayerId.p1),
      p2: PlayerState(id: PlayerId.p2, health: 3),
      rngSeed: 0,
    );
    // Unit-only: must NOT target the player (skipped since no units).
    final t1 = ai.chooseTargets(s, PlayerId.p1, unitOnly);
    expect(t1.every((t) => t.playerId != PlayerId.p2), isTrue);
    // Any-target: may finish the player.
    final t2 = ai.chooseTargets(s, PlayerId.p1, anyTarget);
    expect(t2.any((t) => t.playerId == PlayerId.p2), isTrue);
  });

  test('AI vs AI: 50 different seeds all terminate', () {
    const ai = AiPlayer(tier: AiTier.tactician);
    var p1Wins = 0;
    for (var seed = 0; seed < 50; seed++) {
      var s =
          Game.create(deckP1: aggroDeck(), deckP2: aggroDeck(), seed: seed);
      var guard = 0;
      while (s.winner == null && guard < 200) {
        s = ai.playTurn(s, s.activePlayer);
        if (s.winner != null) break;
        s = Game.nextPhase(s);
        guard++;
      }
      expect(s.winner, isNotNull, reason: 'seed $seed must terminate');
      if (s.winner == PlayerId.p1) p1Wins++;
    }
    // Sanity: neither side wins 100% purely from turn order.
    expect(p1Wins, inInclusiveRange(5, 45));
  });
}
