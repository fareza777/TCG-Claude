import '../effects/interpreter.dart';
import '../model/card_def.dart';
import '../model/enums.dart';
import '../model/game_state.dart';
import '../rules/chain.dart';
import '../rules/combat.dart';
import '../rules/game.dart';

/// Difficulty tiers for the built-in AI.
enum AiTier { greedy, tactician, strategist }

/// A deliberately simple, engine-legal AI. It only uses public engine
/// actions — it cannot cheat.
///
/// Tier greedy: plays the most expensive affordable cards, attacks whenever
/// the trade is not clearly bad.
/// Tier tactician: adds 1-ply board evaluation for attack decisions and
/// holds back obviously bad attacks.
class AiPlayer {
  final AiTier tier;

  const AiPlayer({this.tier = AiTier.greedy});

  /// Play out the main phase: wellspring, generate aether, deploy units.
  ///
  /// Composed from the step-wise helpers below so the PvE UI can replay the
  /// exact same decisions one action at a time (with animation) while the
  /// engine keeps a single source of truth.
  GameState playMainPhase(GameState s, PlayerId me) {
    var state = playResources(s, me);

    while (true) {
      final r = deployNextUnit(state, me);
      if (r == null) break;
      state = r.state;
    }

    while (true) {
      final sp = nextSpell(state, me);
      if (sp == null) break;
      try {
        state = Chain.resolveAll(
            Chain.cast(state, me, sp.cardId, targets: sp.targets));
      } on StateError {
        break; // should not happen — nextSpell dry-runs — but stay safe
      }
      if (state.winner != null) return state;
    }
    return state;
  }

  /// Step 1–2: play a wellspring (if any) and exert every wellspring for
  /// aether. Produces no visible "play" — pure resource setup.
  GameState playResources(GameState s, PlayerId me) {
    var state = s;
    final p = state.player(me);
    final wellsprings =
        p.hand.where((c) => c.def.type == CardType.wellspring).toList();
    if (wellsprings.isNotEmpty && !p.playedWellspringThisTurn) {
      state = Game.playWellspring(state, me, wellsprings.first.instanceId);
    }
    for (final c in state.player(me).arena.toList()) {
      if (c.def.type == CardType.wellspring && !c.exerted) {
        state = Game.exertForAether(state, me, c.instanceId);
      }
    }
    return state;
  }

  /// Step 3 (one iteration): deploy the single most-expensive affordable unit.
  /// Returns the new state and the deployed unit's instance id, or null when
  /// no unit can be played.
  ({GameState state, int deployedId})? deployNextUnit(GameState s, PlayerId me) {
    final hand = s
        .player(me)
        .hand
        .where((c) => c.def.type == CardType.unit)
        .toList()
      ..sort((a, b) => b.def.totalCost.compareTo(a.def.totalCost));
    for (final card in hand) {
      try {
        final next = Game.playUnit(s, me, card.instanceId,
            chosen: chooseTargets(s, me, card.def));
        return (state: next, deployedId: card.instanceId);
      } on StateError {
        continue; // cannot afford — try a cheaper one
      }
    }
    return null;
  }

  /// Step 4 (one iteration): pick the next spell to cast (cheapest first) and
  /// its targets, dry-run-validated as castable. Returns null when nothing is
  /// worth casting. [unitTargetId] is the aimed-at unit for UI targeting FX.
  ({int cardId, List<EffectTarget> targets, int? unitTargetId})? nextSpell(
      GameState s, PlayerId me) {
    final spells = s
        .player(me)
        .hand
        .where((c) =>
            c.def.type == CardType.rite || c.def.type == CardType.ritual)
        .toList()
      ..sort((a, b) => a.def.totalCost.compareTo(b.def.totalCost));
    for (final card in spells) {
      final targets = chooseTargets(s, me, card.def);
      if (requiresUnitTarget(card.def) &&
          targets.every((t) => t.instanceId == null)) {
        continue; // removal with no board — hold it
      }
      try {
        Chain.cast(s, me, card.instanceId, targets: targets); // dry run
      } on StateError {
        continue; // not affordable / illegal — skip
      }
      int? unitTargetId;
      for (final t in targets) {
        if (t.instanceId != null) {
          unitTargetId = t.instanceId;
          break;
        }
      }
      return (
        cardId: card.instanceId,
        targets: targets,
        unitTargetId: unitTargetId
      );
    }
    return null;
  }

  /// Supply targets for every CHOOSE selector in [def]'s effects, in order.
  /// Damage prefers the biggest enemy unit (or the enemy player when the
  /// board is empty / lethal is available); removal picks the biggest unit.
  List<EffectTarget> chooseTargets(GameState s, PlayerId me, CardDef def) {
    final enemyUnits = s
        .player(me.opponent)
        .arena
        .where((c) => c.def.type == CardType.unit)
        .toList()
      ..sort((a, b) => (b.might + b.guard).compareTo(a.might + a.guard));
    final myUnits = s
        .player(me)
        .arena
        .where((c) => c.def.type == CardType.unit)
        .toList()
      ..sort((a, b) => (b.might + b.guard).compareTo(a.might + a.guard));

    final targets = <EffectTarget>[];
    for (final block in def.effects) {
      for (final raw in (block['effects'] as List? ?? const [])) {
        final effect = raw as Map;
        final sel = (effect['target'] as Map?)?['select'];
        if (sel != 'CHOOSE') continue;
        final op = effect['op'] as String;
        switch (op) {
          case 'DEAL_DAMAGE':
            final amount = (effect['amount'] as int?) ?? 0;
            final oppHealth = s.player(me.opponent).health;
            // Only "any target" spells may hit the player; "target Unit"
            // spells must pick a Unit (or be skipped if none exist).
            final canHitPlayer =
                def.text.toLowerCase().contains('any target');
            if (canHitPlayer &&
                (oppHealth <= amount || enemyUnits.isEmpty)) {
              targets.add(EffectTarget.player(me.opponent));
            } else if (enemyUnits.isNotEmpty) {
              targets.add(EffectTarget.unit(enemyUnits.first.instanceId));
            } else {
              targets.add(const EffectTarget.player(null)); // skipped
            }
          case 'DESTROY':
          case 'RETURN_TO_HAND':
            if (enemyUnits.isNotEmpty) {
              targets.add(EffectTarget.unit(enemyUnits.first.instanceId));
            } else {
              targets.add(const EffectTarget.player(null)); // skipped
            }
          case 'BUFF':
          case 'ADD_COUNTER':
            // Buff our own strongest Unit.
            if (myUnits.isNotEmpty) {
              targets.add(EffectTarget.unit(myUnits.first.instanceId));
            } else {
              targets.add(const EffectTarget.player(null)); // skipped
            }
          default:
            targets.add(EffectTarget.player(me.opponent));
        }
      }
    }
    return targets;
  }

  /// Choose an instant-speed (Rite) response to the spell currently on the
  /// chain, or null to pass. Gives the AI real counterplay on the human's
  /// turn: it will counter an incoming spell when it can, and — on the hardest
  /// tier — snipe a genuine threat with instant burn.
  ({int cardId, List<EffectTarget> targets, int? unitTargetId})? chooseResponse(
      GameState s, PlayerId me) {
    if (s.chain.isEmpty) return null;
    final topCounterable = !s.chain.last.uncounterable;
    final rites = s
        .player(me)
        .hand
        .where((c) => c.def.type == CardType.rite)
        .toList()
      ..sort((a, b) => a.def.totalCost.compareTo(b.def.totalCost));

    // 1) Counter the incoming spell if we hold a counter and it is legal.
    for (final card in rites) {
      if (!_hasOp(card.def, 'COUNTER_SPELL') || !topCounterable) continue;
      if (_castable(s, me, card.instanceId, const [])) {
        return (cardId: card.instanceId, targets: const [], unitTargetId: null);
      }
    }

    // 2) Strategist only: respond by killing a real threat with instant burn.
    if (tier == AiTier.strategist) {
      for (final card in rites) {
        if (!_hasOp(card.def, 'DEAL_DAMAGE')) continue;
        final targets = chooseTargets(s, me, card.def);
        int? unitId;
        for (final t in targets) {
          if (t.instanceId != null) {
            unitId = t.instanceId;
            break;
          }
        }
        if (unitId == null) continue;
        CardInstance? u;
        for (final c in s.player(me.opponent).arena) {
          if (c.instanceId == unitId) u = c;
        }
        if (u == null) continue;
        final amount = _firstDamageAmount(card.def);
        final killable = u.guard - u.damage <= amount && (u.might + u.guard) >= 4;
        if (killable && _castable(s, me, card.instanceId, targets)) {
          return (cardId: card.instanceId, targets: targets, unitTargetId: unitId);
        }
      }
    }
    return null;
  }

  bool _hasOp(CardDef def, String op) {
    for (final block in def.effects) {
      for (final e in (block['effects'] as List? ?? const [])) {
        if ((e as Map)['op'] == op) return true;
      }
    }
    return false;
  }

  int _firstDamageAmount(CardDef def) {
    for (final block in def.effects) {
      for (final e in (block['effects'] as List? ?? const [])) {
        if ((e as Map)['op'] == 'DEAL_DAMAGE') return (e['amount'] as int?) ?? 0;
      }
    }
    return 0;
  }

  bool _castable(GameState s, PlayerId me, int cardId, List<EffectTarget> t) {
    try {
      Chain.cast(s, me, cardId, targets: t);
      return true;
    } on StateError {
      return false;
    }
  }

  bool requiresUnitTarget(CardDef def) {
    final anyTarget = def.text.toLowerCase().contains('any target');
    for (final block in def.effects) {
      for (final raw in (block['effects'] as List? ?? const [])) {
        final effect = raw as Map;
        final op = effect['op'] as String;
        final sel = (effect['target'] as Map?)?['select'];
        if (sel != 'CHOOSE') continue;
        if (op == 'DESTROY' || op == 'RETURN_TO_HAND') return true;
        if (op == 'DEAL_DAMAGE' && !anyTarget) return true;
        if (op == 'BUFF') return true; // needs a Unit to buff
      }
    }
    return false;
  }

  // ── board evaluation (Strategist) ─────────────────────────────────────
  static double _keywordValue(Keyword k) => switch (k) {
        Keyword.venom => 1.5,
        Keyword.leech => 1.5,
        Keyword.soar => 1.0,
        Keyword.rampage => 1.0,
        Keyword.alert => 1.0,
        Keyword.swiftstrike => 1.0,
        Keyword.dread => 1.0,
        Keyword.aegis => 1.0,
        Keyword.rush => 0.5,
        Keyword.intercept => 0.5,
        Keyword.bulwark => 0.5,
        Keyword.ambush => 0.5,
      };

  /// Score the state from [me]'s perspective. Higher is better for [me].
  double _evaluate(GameState s, PlayerId me) {
    double boardValue(PlayerState p) {
      var v = 0.0;
      for (final c in p.arena) {
        if (c.def.type != CardType.unit) continue;
        v += c.might * 1.0 + c.guard * 0.8;
        for (final kw in c.def.keywords) {
          v += _keywordValue(kw);
        }
      }
      return v;
    }

    final my = s.player(me), opp = s.player(me.opponent);
    final board = boardValue(my) - boardValue(opp);
    final cardAdv = (my.hand.length - opp.hand.length) * 1.4;
    final hp = (my.health - opp.health) * 0.4;
    return board + cardAdv + hp;
  }

  /// Choose attackers. Greedy: attack with everything able. Tactician:
  /// hold back a unit if the defender has a strictly better blocker.
  /// Strategist: 1-ply lookahead — simulate the opponent's best blocks and
  /// prune attackers that lower the resulting board evaluation.
  List<int> chooseAttackers(GameState s, PlayerId me) {
    final myUnits = s
        .player(me)
        .arena
        .where((c) =>
            c.canAttack && !c.def.keywords.contains(Keyword.bulwark))
        .toList();
    if (myUnits.isEmpty) return const [];
    if (tier == AiTier.greedy) {
      return [for (final c in myUnits) c.instanceId];
    }
    if (tier == AiTier.tactician) {
      final blockers = s
          .player(me.opponent)
          .arena
          .where((c) => c.def.type == CardType.unit && !c.exerted)
          .toList();
      final attackers = <int>[];
      for (final unit in myUnits) {
        final losesTrade = blockers.any((b) =>
            b.might >= unit.guard - unit.damage && unit.might < b.guard);
        if (!losesTrade || _raceIsOn(s, me)) {
          attackers.add(unit.instanceId);
        }
      }
      return attackers;
    }

    // Strategist — simulate and prune.
    double scoreIf(List<int> atk) {
      if (atk.isEmpty) return _evaluate(s, me);
      try {
        var sim = Combat.declareAttackers(s, me, atk);
        final blocks =
            const AiPlayer(tier: AiTier.tactician).chooseBlocks(sim, me.opponent, atk);
        sim = Combat.resolveDamage(sim, me, blocks);
        if (sim.winner == me) return 1e9; // lethal — always take it
        return _evaluate(sim, me);
      } on StateError {
        return -1e9;
      }
    }

    final noAttack = _evaluate(s, me);
    var chosen = [for (final c in myUnits) c.instanceId];
    var best = scoreIf(chosen);
    var improving = true;
    while (improving && chosen.length > 1) {
      improving = false;
      int? removeIdx;
      var bestAlt = best;
      for (var i = 0; i < chosen.length; i++) {
        final alt = [...chosen]..removeAt(i);
        final sc = scoreIf(alt);
        if (sc > bestAlt) {
          bestAlt = sc;
          removeIdx = i;
        }
      }
      if (removeIdx != null) {
        chosen.removeAt(removeIdx);
        best = bestAlt;
        improving = true;
      }
    }
    // If not attacking is clearly best (and we're not racing for lethal), pass.
    if (best < noAttack && !_raceIsOn(s, me)) {
      final single = scoreIf(chosen.take(1).toList());
      if (single < noAttack) return const [];
    }
    return chosen;
  }

  /// Assign blockers against declared attackers. Blocks when the trade is
  /// favorable or lethal damage must be prevented.
  List<AttackDeclaration> chooseBlocks(
    GameState s,
    PlayerId me,
    List<int> incomingAttackerIds,
  ) {
    final available = s
        .player(me)
        .arena
        .where((c) =>
            c.def.type == CardType.unit &&
            (!c.exerted || c.keywords.contains(Keyword.ambush)))
        .toList();
    final attackers = [
      for (final id in incomingAttackerIds)
        s.player(me.opponent).arena.firstWhere((c) => c.instanceId == id),
    ]..sort((a, b) => b.might.compareTo(a.might));

    final declarations = <AttackDeclaration>[];
    final used = <int>{};
    var unblockedDamage =
        attackers.fold(0, (sum, a) => sum + a.might);

    for (final atk in attackers) {
      CardInstance? best;
      for (final b in available) {
        if (used.contains(b.instanceId)) continue;
        if (!_canBlock(atk, b)) continue;
        final kills = b.might >= atk.guard - atk.damage;
        final survives = atk.might < b.guard;
        final mustChump =
            unblockedDamage >= s.player(me).health && tier != AiTier.greedy;
        if ((kills && survives) || (kills && b.might <= atk.might) || mustChump) {
          if (best == null || b.might > best.might) best = b;
        }
      }
      if (best != null &&
          !(atk.def.keywords.contains(Keyword.dread))) {
        used.add(best.instanceId);
        unblockedDamage -= atk.might;
        declarations.add(AttackDeclaration(
            attackerId: atk.instanceId, blockerIds: [best.instanceId]));
      } else {
        declarations.add(AttackDeclaration(attackerId: atk.instanceId));
      }
    }
    return declarations;
  }

  bool _canBlock(CardInstance attacker, CardInstance blocker) {
    if (attacker.def.keywords.contains(Keyword.soar) &&
        !blocker.def.keywords.contains(Keyword.soar) &&
        !blocker.def.keywords.contains(Keyword.intercept)) {
      return false;
    }
    return true;
  }

  /// True when we are ahead on the HP race and should push damage.
  bool _raceIsOn(GameState s, PlayerId me) =>
      s.player(me).health > s.player(me.opponent).health + 5;

  /// Play one full turn (main1 → combat → main2). Returns the state at end
  /// phase, ready for [Game.nextPhase] to pass the turn.
  ///
  /// [defenderAi]: in simulation, the opponent's blocks are chosen by this
  /// AI. In PvE the human UI supplies blocks instead and this stays null
  /// (combat is then driven by the UI layer).
  GameState playTurn(GameState s, PlayerId me, {AiPlayer? defenderAi}) {
    var state = s;
    assert(state.activePlayer == me);

    // Refresh & draw are driven by the turn loop (Game.nextPhase).
    if (state.phase == Phase.refresh) state = Game.nextPhase(state);
    if (state.phase == Phase.draw) state = Game.nextPhase(state);
    if (state.winner != null) return state;

    state = playMainPhase(state, me); // main1
    if (state.winner != null) return state;
    state = Game.nextPhase(state); // -> combat

    final attackerIds = chooseAttackers(state, me);
    if (attackerIds.isNotEmpty) {
      state = Combat.declareAttackers(state, me, attackerIds);
      final hasBlockers = state
          .player(me.opponent)
          .arena
          .any((c) => c.def.type == CardType.unit && !c.exerted);
      if (defenderAi != null && hasBlockers) {
        final blocks =
            defenderAi.chooseBlocks(state, me.opponent, attackerIds);
        state = Combat.resolveDamage(state, me, blocks);
      } else if (!hasBlockers) {
        state = Combat.resolveDamage(state, me, [
          for (final id in attackerIds) AttackDeclaration(attackerId: id),
        ]);
      }
    }
    if (state.winner != null) return state;

    state = Game.nextPhase(state); // -> main2
    state = playMainPhase(state, me);
    if (state.winner != null) return state;
    state = Game.nextPhase(state); // -> end
    return state;
  }
}
