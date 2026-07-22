import 'dart:math';

import '../effects/interpreter.dart';
import '../model/card_def.dart';
import '../model/enums.dart';
import '../model/game_state.dart';

/// Core rules driver: game setup and turn flow.
/// Pure functions — each returns a new [GameState].
class Game {
  /// Create a new game from two 40-card deck lists. Deterministic via [seed].
  /// [firstPlayer] takes the first turn (set by a coin flip in skirmish); the
  /// other player draws one extra card as second-player compensation.
  static GameState create({
    required List<CardDef> deckP1,
    required List<CardDef> deckP2,
    required int seed,
    PlayerId firstPlayer = PlayerId.p1,
  }) {
    var instanceId = 1;
    List<CardInstance> build(List<CardDef> defs, PlayerId owner, Random rng) {
      final cards = [
        for (final def in defs)
          CardInstance(instanceId: instanceId++, def: def, owner: owner),
      ];
      cards.shuffle(rng);
      return cards;
    }

    final rng = Random(seed);
    final d1 = build(deckP1, PlayerId.p1, rng);
    final d2 = build(deckP2, PlayerId.p2, rng);

    // The player on the play draws 5; the player on the draw gets 6.
    final p1First = firstPlayer == PlayerId.p1;
    final h1 = p1First ? 5 : 6;
    final h2 = p1First ? 6 : 5;

    return GameState(
      p1: PlayerState(
          id: PlayerId.p1, deck: d1.sublist(h1), hand: d1.sublist(0, h1)),
      p2: PlayerState(
          id: PlayerId.p2, deck: d2.sublist(h2), hand: d2.sublist(0, h2)),
      rngSeed: seed,
      nextInstanceId: instanceId,
      phase: Phase.main1,
      activePlayer: firstPlayer,
      firstPlayer: firstPlayer,
    );
  }

  /// Redraw the opening hand once (mulligan): shuffle the current hand back
  /// into the deck and draw the same number of cards. Deterministic from the
  /// game seed so replays match.
  static GameState redraw(GameState s, PlayerId pid) {
    final p = s.player(pid);
    final n = p.hand.length;
    final combined = [...p.hand, ...p.deck];
    final rng = Random(s.rngSeed ^ ((pid.index + 1) * 7919));
    combined.shuffle(rng);
    return s.withPlayer(p.copyWith(
      hand: combined.sublist(0, n),
      deck: combined.sublist(n),
    ));
  }

  /// Draw [count] cards. Drawing from an empty deck loses the game.
  static GameState draw(GameState s, PlayerId pid, [int count = 1]) {
    var p = s.player(pid);
    var hand = [...p.hand];
    var deck = [...p.deck];
    for (var i = 0; i < count; i++) {
      if (deck.isEmpty) {
        return s.copyWith(winner: pid.opponent);
      }
      hand.add(deck.removeAt(0));
    }
    return s.withPlayer(p.copyWith(hand: hand, deck: deck));
  }

  /// Advance to the next phase; wraps into the opponent's turn after End.
  static GameState nextPhase(GameState s) {
    switch (s.phase) {
      case Phase.refresh:
        return s.copyWith(phase: Phase.draw);
      case Phase.draw:
        // The player on the play skips the draw on turn 1.
        final skip = s.turnNumber == 1 && s.activePlayer == s.firstPlayer;
        final drawn = skip ? s : draw(s, s.activePlayer);
        return drawn.copyWith(phase: Phase.main1);
      case Phase.main1:
        return s.copyWith(phase: Phase.combat);
      case Phase.combat:
        return s.copyWith(phase: Phase.main2);
      case Phase.main2:
        return s.copyWith(phase: Phase.end);
      case Phase.end:
        return _endTurn(s);
    }
  }

  static GameState _endTurn(GameState s) {
    // Cleanup: combat damage clears from ALL Units at end of turn — including
    // the defending player's Units that were hurt while blocking. Clear the
    // active player's turn flags too.
    var active = s.player(s.activePlayer);
    active = active.copyWith(
      arena: [
        for (final c in active.arena)
          c.copyWith(
              damage: 0,
              summonedThisTurn: false,
              tempMight: 0,
              tempGuard: 0,
              tempKeywords: const {}),
      ],
      aetherPool: const {},
      playedWellspringThisTurn: false,
      usedAttuneThisTurn: false,
    );
    var next = s.withPlayer(active);

    final incoming = s.activePlayer.opponent;
    var incomingP = next.player(incoming);
    // Refresh: ready exerted cards, clear block damage and expiring buffs.
    incomingP = incomingP.copyWith(
      arena: [
        for (final c in incomingP.arena)
          c.copyWith(
              exerted: false,
              damage: 0,
              tempMight: 0,
              tempGuard: 0,
              tempKeywords: const {}),
      ],
      aetherPool: const {},
    );
    next = next.withPlayer(incomingP);

    return next.copyWith(
      activePlayer: incoming,
      phase: Phase.refresh,
      turnNumber:
          incoming == s.firstPlayer ? s.turnNumber + 1 : s.turnNumber,
    );
  }

  /// Play a Wellspring from hand (max 1 per turn).
  static GameState playWellspring(GameState s, PlayerId pid, int instanceId) {
    final p = s.player(pid);
    if (p.playedWellspringThisTurn) {
      throw StateError('Already played a Wellspring this turn');
    }
    final card = p.hand.firstWhere((c) => c.instanceId == instanceId);
    if (card.def.type != CardType.wellspring) {
      throw StateError('${card.def.name} is not a Wellspring');
    }
    return s.withPlayer(p.copyWith(
      hand: [...p.hand]..removeWhere((c) => c.instanceId == instanceId),
      arena: [...p.arena, card],
      playedWellspringThisTurn: true,
    ));
  }

  /// Exert a Wellspring in the arena to add its Aether to the pool.
  static GameState exertForAether(GameState s, PlayerId pid, int instanceId) {
    final p = s.player(pid);
    final card = p.arena.firstWhere((c) => c.instanceId == instanceId);
    if (card.def.type != CardType.wellspring || card.exerted) {
      throw StateError('Cannot exert ${card.def.name} for Aether');
    }
    final dominion = card.def.dominions.first;
    final pool = Map<Dominion, int>.from(p.aetherPool);
    pool[dominion] = (pool[dominion] ?? 0) + 1;
    return s.withPlayer(p.copyWith(
      arena: [
        for (final c in p.arena)
          c.instanceId == instanceId ? c.copyWith(exerted: true) : c,
      ],
      aetherPool: pool,
    ));
  }

  /// Pay a card's cost from the player's Aether pool.
  /// Dominion-specific costs consume matching Aether; generic consumes any.
  static Map<Dominion, int> payCost(CardDef def, Map<Dominion, int> pool) {
    final remaining = Map<Dominion, int>.from(pool);
    for (final entry in def.costDominion.entries) {
      final have = remaining[entry.key] ?? 0;
      if (have < entry.value) {
        throw StateError('Insufficient ${entry.key.name} Aether');
      }
      remaining[entry.key] = have - entry.value;
    }
    var generic = def.costGeneric;
    for (final d in Dominion.values) {
      if (generic == 0) break;
      final have = remaining[d] ?? 0;
      final used = have < generic ? have : generic;
      remaining[d] = have - used;
      generic -= used;
    }
    if (generic > 0) throw StateError('Insufficient Aether');
    return remaining;
  }

  /// Play a Unit from hand during a main phase. Fires its ON_ENTER_ARENA
  /// triggers; CHOOSE targets are supplied by the caller via [chosen].
  static GameState playUnit(
    GameState s,
    PlayerId pid,
    int instanceId, {
    List<EffectTarget> chosen = const [],
  }) {
    if (s.phase != Phase.main1 && s.phase != Phase.main2) {
      throw StateError('Units can only be played in a main phase');
    }
    final p = s.player(pid);
    final card = p.hand.firstWhere((c) => c.instanceId == instanceId);
    if (card.def.type != CardType.unit) {
      throw StateError('${card.def.name} is not a Unit');
    }
    final poolAfter = payCost(card.def, p.aetherPool);
    final placed = card.copyWith(summonedThisTurn: true);
    var next = s.withPlayer(p.copyWith(
      hand: [...p.hand]..removeWhere((c) => c.instanceId == instanceId),
      arena: [...p.arena, placed],
      aetherPool: poolAfter,
    ));
    for (final block in card.def.effects) {
      if (block['trigger'] == 'ON_ENTER_ARENA') {
        next = EffectInterpreter.applyTrigger(next, placed, block,
            chosen: chosen);
        if (next.winner != null) break;
      }
    }
    return next;
  }
}
