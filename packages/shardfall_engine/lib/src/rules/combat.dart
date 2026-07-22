import '../effects/interpreter.dart';
import '../model/enums.dart';
import '../model/game_state.dart';

/// A declared attack: one attacker, optionally blocked by ordered blockers.
class AttackDeclaration {
  final int attackerId;
  final List<int> blockerIds; // damage assignment order

  const AttackDeclaration({required this.attackerId, this.blockerIds = const []});
}

/// Combat resolution for one combat phase.
///
/// Keyword handling:
/// - Soar: only blockable by Soar or Intercept.
/// - Dread: must be blocked by 2+ Units or none.
/// - Bulwark: cannot attack.
/// - Alert: attacking does not exert.
/// - Swiftstrike: deals damage before normal damage.
/// - Venom: any damage dealt to a Unit destroys it.
/// - Rampage: excess damage over blockers' guard hits the defending player.
/// - Leech: controller heals for damage dealt.
/// - Ambush: may block even while exerted (defensive vigilance).
/// - Aegis N: prevents N combat damage each combat.
class Combat {
  /// Validate and mark attackers (exert unless Alert).
  static GameState declareAttackers(
    GameState s,
    PlayerId attacker,
    List<int> attackerIds,
  ) {
    var p = s.player(attacker);
    final arena = [...p.arena];
    for (final id in attackerIds) {
      final i = arena.indexWhere((c) => c.instanceId == id);
      if (i < 0) throw StateError('Attacker $id not in arena');
      final c = arena[i];
      if (!c.canAttack) throw StateError('${c.def.name} cannot attack');
      if (c.keywords.contains(Keyword.bulwark)) {
        throw StateError('${c.def.name} has Bulwark and cannot attack');
      }
      final exerts = !c.keywords.contains(Keyword.alert);
      arena[i] = c.copyWith(exerted: exerts ? true : c.exerted);
    }
    var out = s.withPlayer(p.copyWith(arena: arena));

    // Fire ON_ATTACK triggers for each attacker. Untargeted selectors resolve;
    // CHOOSE selectors with no supplied target are skipped (like death triggers).
    for (final id in attackerIds) {
      final unit =
          out.player(attacker).arena.firstWhere((c) => c.instanceId == id);
      for (final block in unit.def.effects) {
        if (block['trigger'] == 'ON_ATTACK') {
          out = EffectInterpreter.applyTrigger(out, unit, block);
          if (out.winner != null) return out;
        }
      }
    }
    return out;
  }

  /// Validate a block assignment against keyword constraints.
  static void validateBlocks(
    GameState s,
    PlayerId defender,
    List<AttackDeclaration> attacks,
  ) {
    final defArena = s.player(defender).arena;
    final attArena = s.player(defender.opponent).arena;
    for (final atk in attacks) {
      final attacker =
          attArena.firstWhere((c) => c.instanceId == atk.attackerId);
      if (atk.blockerIds.isEmpty) continue;
      if (attacker.keywords.contains(Keyword.dread) &&
          atk.blockerIds.length < 2) {
        throw StateError('${attacker.def.name} has Dread: needs 2+ blockers');
      }
      for (final bid in atk.blockerIds) {
        final blocker = defArena.firstWhere((c) => c.instanceId == bid);
        if (blocker.exerted && !blocker.keywords.contains(Keyword.ambush)) {
          throw StateError('${blocker.def.name} is exerted and cannot block');
        }
        if (attacker.keywords.contains(Keyword.soar) &&
            !blocker.keywords.contains(Keyword.soar) &&
            !blocker.keywords.contains(Keyword.intercept)) {
          throw StateError('${blocker.def.name} cannot block Soar');
        }
      }
    }
  }

  /// Resolve combat damage. Returns the post-combat state with dead units
  /// moved to Ruins and player damage applied.
  static GameState resolveDamage(
    GameState s,
    PlayerId attackerPid,
    List<AttackDeclaration> attacks,
  ) {
    validateBlocks(s, attackerPid.opponent, attacks);

    final damageToUnit = <int, int>{};
    final venomHit = <int>{};
    var damageToDefender = 0;
    var attackerHeal = 0;
    var defenderHeal = 0;

    CardInstance find(PlayerId pid, int id) =>
        s.player(pid).arena.firstWhere((c) => c.instanceId == id);

    // Two strike windows: swiftstrike first, then normal. Damage within a
    // window is simultaneous: deaths are checked against the snapshot taken
    // at the start of the window, so a unit still strikes back even if it
    // receives lethal damage in the same window.
    for (final swiftWindow in [true, false]) {
      final dmgSnapshot = Map<int, int>.from(damageToUnit);
      final venomSnapshot = Set<int>.from(venomHit);
      for (final atk in attacks) {
        final attacker = find(attackerPid, atk.attackerId);
        // Skip attacker's dealing if it died in an earlier window.
        final attackerDead =
            (dmgSnapshot[atk.attackerId] ?? 0) >= attacker.guard ||
                venomSnapshot.contains(atk.attackerId);

        final attackerStrikesNow =
            attacker.keywords.contains(Keyword.swiftstrike) == swiftWindow;

        if (attackerStrikesNow && !attackerDead) {
          var remaining = attacker.might;
          if (atk.blockerIds.isEmpty) {
            damageToDefender += remaining;
            if (attacker.keywords.contains(Keyword.leech)) {
              attackerHeal += remaining;
            }
          } else {
            for (final bid in atk.blockerIds) {
              if (remaining <= 0) break;
              final blocker = find(attackerPid.opponent, bid);
              final lethal = blocker.guard - (damageToUnit[bid] ?? 0);
              final assign =
                  attacker.keywords.contains(Keyword.venom) ? 1 : lethal;
              final dealt = remaining < assign ? remaining : assign;
              damageToUnit[bid] = (damageToUnit[bid] ?? 0) + dealt;
              if (attacker.keywords.contains(Keyword.venom) && dealt > 0) {
                venomHit.add(bid);
              }
              if (attacker.keywords.contains(Keyword.leech)) {
                attackerHeal += dealt;
              }
              remaining -= dealt;
            }
            if (remaining > 0 &&
                attacker.keywords.contains(Keyword.rampage)) {
              damageToDefender += remaining;
              if (attacker.keywords.contains(Keyword.leech)) {
                attackerHeal += remaining;
              }
            }
          }
        }

        // Blockers strike back in their own window.
        for (final bid in atk.blockerIds) {
          final blocker = find(attackerPid.opponent, bid);
          final blockerDead = (dmgSnapshot[bid] ?? 0) >= blocker.guard ||
              venomSnapshot.contains(bid);
          final blockerStrikesNow =
              blocker.keywords.contains(Keyword.swiftstrike) == swiftWindow;
          if (!blockerStrikesNow || blockerDead) continue;
          damageToUnit[atk.attackerId] =
              (damageToUnit[atk.attackerId] ?? 0) + blocker.might;
          if (blocker.keywords.contains(Keyword.venom) &&
              blocker.might > 0) {
            venomHit.add(atk.attackerId);
          }
          if (blocker.keywords.contains(Keyword.leech)) {
            defenderHeal += blocker.might;
          }
        }
      }
    }

    // Apply results.
    var next = s;
    for (final pid in [attackerPid, attackerPid.opponent]) {
      var p = next.player(pid);
      final alive = <CardInstance>[];
      final dead = <CardInstance>[];
      for (final c in p.arena) {
        // Aegis N prevents up to N of this combat's incoming damage.
        final incoming = damageToUnit[c.instanceId] ?? 0;
        final aegis = c.def.aegisValue;
        final prevented = aegis <= 0
            ? 0
            : (incoming < aegis ? incoming : aegis);
        final dmg = c.damage + (incoming - prevented);
        final killed = (c.def.type == CardType.unit) &&
            (dmg >= c.guard || venomHit.contains(c.instanceId));
        if (killed) {
          dead.add(c.copyWith(damage: dmg));
        } else {
          alive.add(c.copyWith(damage: dmg));
        }
      }
      p = p.copyWith(arena: alive, ruins: [...p.ruins, ...dead]);
      next = next.withPlayer(p);
    }

    var defender = next.player(attackerPid.opponent);
    defender = defender.copyWith(
      health: defender.health - damageToDefender + defenderHeal,
    );
    next = next.withPlayer(defender);

    var attackerP = next.player(attackerPid);
    attackerP = attackerP.copyWith(health: attackerP.health + attackerHeal);
    next = next.withPlayer(attackerP);

    if (defender.health <= 0) {
      next = next.copyWith(winner: attackerPid);
    }
    return next;
  }
}
