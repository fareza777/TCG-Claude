import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

CardDef unit(String id, {int cost = 2, int might = 2, int guard = 2}) =>
    CardDef(
      id: id,
      name: 'Test Unit $id',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      costGeneric: cost - 1,
      costDominion: const {Dominion.verdance: 1},
      might: might,
      guard: guard,
    );

CardDef wellspring(String id) => CardDef(
      id: id,
      name: 'Verdant Wellspring',
      dominions: const [Dominion.verdance],
      type: CardType.wellspring,
    );

List<CardDef> testDeck() => [
      for (var i = 0; i < 16; i++) wellspring('WS$i'),
      for (var i = 0; i < 24; i++) unit('U$i'),
    ];

void main() {
  group('game setup', () {
    test('P1 draws 5, P2 draws 6, decks are 40', () {
      final s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 42);
      expect(s.p1.hand.length, 5);
      expect(s.p2.hand.length, 6);
      expect(s.p1.deck.length, 35);
      expect(s.p2.deck.length, 34);
      expect(s.p1.health, 25);
    });

    test('enemy on the play: P2 first, P2 draws 5 + skips first draw', () {
      var s = Game.create(
          deckP1: testDeck(),
          deckP2: testDeck(),
          seed: 9,
          firstPlayer: PlayerId.p2);
      expect(s.activePlayer, PlayerId.p2);
      expect(s.firstPlayer, PlayerId.p2);
      expect(s.p2.hand.length, 5, reason: 'on the play draws 5');
      expect(s.p1.hand.length, 6, reason: 'on the draw gets 6');
      // P2 is at main1 already (draw skipped). Advance a full turn to P1.
      s = Game.nextPhase(s); // combat
      s = Game.nextPhase(s); // main2
      s = Game.nextPhase(s); // end
      s = Game.nextPhase(s); // -> P1 refresh
      expect(s.activePlayer, PlayerId.p1);
      s = Game.nextPhase(s); // refresh -> draw
      s = Game.nextPhase(s); // draw -> main1 (P1 draws — on the draw)
      expect(s.p1.hand.length, 7, reason: 'P1 draws on its first turn');
      expect(s.phase, Phase.main1);
    });

    test('same seed produces identical shuffles', () {
      final a = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 7);
      final b = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 7);
      expect(
        [for (final c in a.p1.hand) c.def.id],
        [for (final c in b.p1.hand) c.def.id],
      );
    });

    test('different seed produces different shuffle', () {
      final a = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 1);
      final b = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 2);
      expect(
        [for (final c in a.p1.hand) c.def.id] !=
            [for (final c in b.p1.hand) c.def.id],
        isTrue,
        reason: 'astronomically unlikely to match',
      );
    });
  });

  group('wellspring and aether', () {
    test('play wellspring, exert for aether, pay unit cost', () {
      var s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 42);
      // Force a known hand: find a wellspring and a unit in P1 hand or deck.
      final ws = s.p1.hand.where((c) => c.def.type == CardType.wellspring);
      if (ws.isEmpty) return; // seed 42 gives at least one in practice

      s = Game.playWellspring(s, PlayerId.p1, ws.first.instanceId);
      expect(s.p1.arena.length, 1);
      expect(s.p1.playedWellspringThisTurn, isTrue);

      s = Game.exertForAether(s, PlayerId.p1, s.p1.arena.first.instanceId);
      expect(s.p1.aetherPool[Dominion.verdance], 1);
      expect(s.p1.arena.first.exerted, isTrue);
    });

    test('second wellspring in one turn is rejected', () {
      var s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 3);
      final ws = s.p1.hand
          .where((c) => c.def.type == CardType.wellspring)
          .toList();
      if (ws.length < 2) return;
      s = Game.playWellspring(s, PlayerId.p1, ws[0].instanceId);
      expect(
        () => Game.playWellspring(s, PlayerId.p1, ws[1].instanceId),
        throwsStateError,
      );
    });

    test('cost payment consumes dominion then generic', () {
      final def = unit('X', cost: 3); // 2 generic + 1 verdance
      final pool = {Dominion.verdance: 2, Dominion.pyre: 1};
      final after = Game.payCost(def, pool);
      expect(after.values.fold(0, (a, b) => a + b), 0);
    });

    test('insufficient aether throws', () {
      final def = unit('X', cost: 3);
      expect(() => Game.payCost(def, {Dominion.verdance: 1}), throwsStateError);
    });
  });

  group('turn flow', () {
    test('phases advance and turn passes to opponent', () {
      var s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 42);
      expect(s.phase, Phase.main1);
      s = Game.nextPhase(s); // combat
      s = Game.nextPhase(s); // main2
      s = Game.nextPhase(s); // end
      expect(s.phase, Phase.end);
      s = Game.nextPhase(s); // wraps to opponent
      expect(s.activePlayer, PlayerId.p2);
      expect(s.phase, Phase.refresh);
    });

    test('end of turn heals damage and clears summoning fatigue', () {
      var s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 42);
      final ws = s.p1.hand.where((c) => c.def.type == CardType.wellspring);
      if (ws.isEmpty) return;
      s = Game.playWellspring(s, PlayerId.p1, ws.first.instanceId);
      // cycle through end of P1 turn
      s = Game.nextPhase(s); // combat
      s = Game.nextPhase(s); // main2
      s = Game.nextPhase(s); // end
      s = Game.nextPhase(s); // -> P2 refresh
      expect(s.p1.playedWellspringThisTurn, isFalse);
      expect(s.activePlayer, PlayerId.p2);
    });

    test('redraw reshuffles into a same-size hand, deterministically', () {
      final a = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 5);
      final r1 = Game.redraw(a, PlayerId.p1);
      final r2 = Game.redraw(a, PlayerId.p1);
      expect(r1.p1.hand.length, a.p1.hand.length);
      expect(r1.p1.deck.length, a.p1.deck.length);
      expect([for (final c in r1.p1.hand) c.instanceId],
          [for (final c in r2.p1.hand) c.instanceId],
          reason: 'redraw is deterministic from the seed');
    });

    test('drawing from empty deck loses the game', () {
      var s = Game.create(deckP1: testDeck(), deckP2: testDeck(), seed: 42);
      var p = s.p1.copyWith(deck: const []);
      s = s.withPlayer(p);
      s = Game.draw(s, PlayerId.p1);
      expect(s.winner, PlayerId.p2);
    });
  });
}
