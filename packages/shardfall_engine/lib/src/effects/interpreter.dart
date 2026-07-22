import '../model/card_def.dart';
import '../model/enums.dart';
import '../model/game_state.dart';

/// A resolved target for one effect op: either a unit instance or a player.
class EffectTarget {
  final int? instanceId;
  final PlayerId? playerId;

  const EffectTarget.unit(this.instanceId) : playerId = null;
  const EffectTarget.player(this.playerId) : instanceId = null;
}

/// Interprets Effect DSL ops (see data/cards/SCHEMA.md).
///
/// Target *selection* (CHOOSE) is done by the caller (UI or AI) and passed in
/// as [chosen]; selectors like ALL/SELF_PLAYER are resolved here. This keeps
/// the interpreter pure and UI-free.
class EffectInterpreter {
  /// Apply one trigger block (`{trigger, effects: [...]}`) from [source].
  static GameState applyTrigger(
    GameState s,
    CardInstance source,
    Map<String, dynamic> triggerBlock, {
    List<EffectTarget> chosen = const [],
  }) {
    var state = s;
    var chosenIndex = 0;
    for (final raw in (triggerBlock['effects'] as List)) {
      final effect = Map<String, dynamic>.from(raw as Map);
      List<EffectTarget>? targets;
      var skip = false;
      targets = _resolveTargets(state, source, effect, () {
        if (chosenIndex >= chosen.length) {
          // "If able" semantics: a CHOOSE op with no supplied target is
          // skipped instead of crashing (e.g. removal with an empty board).
          skip = true;
          return const EffectTarget.player(null);
        }
        return chosen[chosenIndex++];
      });
      if (skip) continue;
      state = _applyOp(state, source, effect, targets);
      if (state.winner != null) return state;
    }
    return state;
  }

  static List<EffectTarget> _resolveTargets(
    GameState s,
    CardInstance source,
    Map<String, dynamic> effect,
    EffectTarget Function() nextChosen,
  ) {
    final t = effect['target'] as Map<String, dynamic>?;
    if (t == null) return const [];
    final select = (t['select'] as String?) ?? 'CHOOSE';
    switch (select) {
      case 'SELF_PLAYER':
        return [EffectTarget.player(source.owner)];
      case 'OPPONENT_PLAYER':
        return [EffectTarget.player(source.owner.opponent)];
      case 'CHOOSE':
        return [nextChosen()];
      case 'ALL':
        final owner = (t['owner'] as String?) ?? 'ANY';
        final filter = (t['filter'] as Map?) ?? const {};
        final excludeSelf = filter['excludeSelf'] == true;
        final typeFilter = filter['type'] as String?;
        final pids = switch (owner) {
          'SELF' => [source.owner],
          'OPPONENT' => [source.owner.opponent],
          _ => [source.owner, source.owner.opponent],
        };
        return [
          for (final pid in pids)
            for (final c in s.player(pid).arena)
              if (!(excludeSelf && c.instanceId == source.instanceId) &&
                  (typeFilter == null ||
                      c.def.type ==
                          CardType.values.byName(typeFilter.toLowerCase())))
                EffectTarget.unit(c.instanceId),
        ];
      default:
        throw UnsupportedError('Unknown selector: $select');
    }
  }

  static GameState _applyOp(
    GameState s,
    CardInstance source,
    Map<String, dynamic> effect,
    List<EffectTarget> targets,
  ) {
    final op = effect['op'] as String;
    switch (op) {
      case 'DEAL_DAMAGE':
        return _forEachTarget(s, targets, (state, t) {
          final amount = effect['amount'] as int;
          if (t.playerId != null) {
            var p = state.player(t.playerId!);
            p = p.copyWith(health: p.health - amount);
            var next = state.withPlayer(p);
            if (p.health <= 0) {
              next = next.copyWith(winner: t.playerId!.opponent);
            }
            return next;
          }
          return _damageUnit(state, t.instanceId!, amount);
        });

      case 'HEAL':
        return _forEachTarget(s, targets, (state, t) {
          final amount = effect['amount'] as int;
          var p = state.player(t.playerId!);
          return state.withPlayer(p.copyWith(health: p.health + amount));
        });

      case 'DRAW':
        return _drawCards(s, source.owner, effect['amount'] as int);

      case 'DISCARD':
        return _forEachTarget(s, targets, (state, t) {
          var p = state.player(t.playerId!);
          if (p.hand.isEmpty) return state;
          // Caller-supplied choice comes later; default: discard first card.
          final card = p.hand.first;
          return state.withPlayer(p.copyWith(
            hand: [...p.hand]..removeAt(0),
            ruins: [...p.ruins, card],
          ));
        });

      case 'ADD_COUNTER':
        return _forEachTarget(s, targets, (state, t) {
          final amount = effect['amount'] as int;
          return _mapUnit(state, t.instanceId!,
              (c) => c.copyWith(plusCounters: c.plusCounters + amount));
        });

      case 'BUFF':
        // Temporary +might/+guard until end of turn (combat trick).
        return _forEachTarget(s, targets, (state, t) {
          final m = (effect['might'] as int?) ?? 0;
          final g = (effect['guard'] as int?) ?? 0;
          return _mapUnit(
              state,
              t.instanceId!,
              (c) => c.copyWith(
                  tempMight: c.tempMight + m, tempGuard: c.tempGuard + g));
        });

      case 'DESTROY':
        return _forEachTarget(s, targets, (state, t) {
          CardInstance? victim;
          for (final pid in PlayerId.values) {
            for (final c in state.player(pid).arena) {
              if (c.instanceId == t.instanceId) victim = c;
            }
          }
          var next = _destroyUnit(state, t.instanceId!);
          if (victim != null) next = fireDeathTriggers(next, [victim]);
          return next;
        });

      case 'RETURN_TO_HAND':
        return _forEachTarget(s, targets, (state, t) {
          for (final pid in PlayerId.values) {
            final p = state.player(pid);
            final i = p.arena.indexWhere((c) => c.instanceId == t.instanceId);
            if (i >= 0) {
              final card = p.arena[i]
                  .copyWith(damage: 0, exerted: false, summonedThisTurn: false);
              return state.withPlayer(p.copyWith(
                arena: [...p.arena]..removeAt(i),
                hand: [...p.hand, card],
              ));
            }
          }
          return state;
        });

      case 'GAIN_AETHER':
        final dominionName = effect['dominion'] as String?;
        final dominion = dominionName == null
            ? Dominion.neutral
            : Dominion.values.byName(dominionName.toLowerCase());
        var p = s.player(source.owner);
        final pool = Map<Dominion, int>.from(p.aetherPool);
        pool[dominion] = (pool[dominion] ?? 0) + (effect['amount'] as int? ?? 1);
        return s.withPlayer(p.copyWith(aetherPool: pool));

      case 'UNCOUNTERABLE':
        return s; // static marker, checked by the chain resolver

      case 'GRANT_KEYWORD':
        // Give a target Unit a keyword until end of turn (cleared in _endTurn).
        return _forEachTarget(s, targets, (state, t) {
          if (t.instanceId == null) return state;
          final kw = Keyword.values
              .byName((effect['keyword'] as String).toLowerCase());
          return _mapUnit(state, t.instanceId!,
              (c) => c.copyWith(tempKeywords: {...c.tempKeywords, kw}));
        });

      case 'COUNTER_SPELL':
        // Counter the spell directly beneath this one on the chain. This op
        // runs while the counter itself has already been popped by resolveTop,
        // so chain.last is its target. Respects UNCOUNTERABLE.
        if (s.chain.isEmpty) return s;
        final idx = s.chain.length - 1;
        if (s.chain[idx].uncounterable) return s;
        final chain = [...s.chain];
        chain[idx] = chain[idx].copyWith(countered: true);
        return s.copyWith(chain: chain);

      case 'SEARCH_DECK':
        // Find the first Unit/card matching a filter and move it to hand
        // (default) or the Arena. Simplified: takes the first match.
        final filter = (effect['filter'] as Map?) ?? const {};
        final typeName = filter['type'] as String?;
        final dest = (effect['destination'] as String?) ?? 'HAND';
        final p = s.player(source.owner);
        final idx = p.deck.indexWhere((c) =>
            typeName == null ||
            c.def.type == CardType.values.byName(typeName.toLowerCase()));
        if (idx < 0) return s;
        final found = p.deck[idx];
        final deck = [...p.deck]..removeAt(idx);
        if (dest == 'ARENA_EXERTED') {
          return s.withPlayer(p.copyWith(
              deck: deck, arena: [...p.arena, found.copyWith(exerted: true)]));
        }
        return s.withPlayer(p.copyWith(deck: deck, hand: [...p.hand, found]));

      case 'CREATE_TOKEN':
        final spec = Map<String, dynamic>.from(effect['token'] as Map);
        final amount = (effect['amount'] as int?) ?? 1;
        final tokenDef = CardDef(
          id: 'TOKEN-${spec['name']}',
          name: spec['name'] as String,
          dominions: [
            for (final d in (spec['dominion'] as List? ?? const []))
              Dominion.values.byName((d as String).toLowerCase()),
          ],
          type: CardType.unit,
          subtype: (spec['subtype'] as String?) ?? 'Token',
          might: spec['might'] as int? ?? 1,
          guard: spec['guard'] as int? ?? 1,
          keywords: {
            for (final k in (spec['keywords'] as List? ?? const []))
              Keyword.values.byName((k as String).toLowerCase()),
          },
          text: (spec['text'] as String?) ?? '',
        );
        var next = s;
        var nextId = s.nextInstanceId;
        var p2 = next.player(source.owner);
        final tokens = [
          for (var i = 0; i < amount; i++)
            CardInstance(
                instanceId: nextId++,
                def: tokenDef,
                owner: source.owner,
                summonedThisTurn: true),
        ];
        return next
            .withPlayer(p2.copyWith(arena: [...p2.arena, ...tokens]))
            .copyWith(nextInstanceId: nextId);

      default:
        throw UnsupportedError('Unknown op: $op');
    }
  }

  /// Fire ON_DEATH triggers for a set of units that just left the Arena.
  /// Effects with untargeted selectors (self/opponent/all/gain) resolve;
  /// CHOOSE selectors without a supplied target are skipped.
  static GameState fireDeathTriggers(
      GameState s, List<CardInstance> dead) {
    var state = s;
    for (final unit in dead) {
      for (final block in unit.def.effects) {
        if (block['trigger'] == 'ON_DEATH') {
          state = applyTrigger(state, unit, block);
          if (state.winner != null) return state;
        }
      }
    }
    return state;
  }

  // -- helpers ------------------------------------------------------------

  static GameState _forEachTarget(
    GameState s,
    List<EffectTarget> targets,
    GameState Function(GameState, EffectTarget) fn,
  ) {
    var state = s;
    for (final t in targets) {
      state = fn(state, t);
      if (state.winner != null) break;
    }
    return state;
  }

  static GameState _drawCards(GameState s, PlayerId pid, int count) {
    var p = s.player(pid);
    var hand = [...p.hand];
    var deck = [...p.deck];
    for (var i = 0; i < count; i++) {
      if (deck.isEmpty) return s.copyWith(winner: pid.opponent);
      hand.add(deck.removeAt(0));
    }
    return s.withPlayer(p.copyWith(hand: hand, deck: deck));
  }

  static GameState _mapUnit(
    GameState s,
    int instanceId,
    CardInstance Function(CardInstance) fn,
  ) {
    for (final pid in PlayerId.values) {
      final p = s.player(pid);
      final i = p.arena.indexWhere((c) => c.instanceId == instanceId);
      if (i >= 0) {
        final arena = [...p.arena];
        arena[i] = fn(arena[i]);
        return s.withPlayer(p.copyWith(arena: arena));
      }
    }
    return s;
  }

  static GameState _damageUnit(GameState s, int instanceId, int amount) {
    var next = _mapUnit(
        s, instanceId, (c) => c.copyWith(damage: c.damage + amount));
    return _sweepDead(next);
  }

  static GameState _destroyUnit(GameState s, int instanceId) {
    for (final pid in PlayerId.values) {
      final p = s.player(pid);
      final i = p.arena.indexWhere((c) => c.instanceId == instanceId);
      if (i >= 0) {
        final card = p.arena[i];
        return s.withPlayer(p.copyWith(
          arena: [...p.arena]..removeAt(i),
          ruins: [...p.ruins, card],
        ));
      }
    }
    return s;
  }

  static GameState _sweepDead(GameState s) {
    var next = s;
    for (final pid in PlayerId.values) {
      final p = next.player(pid);
      final dead = p.arena.where((c) => c.isDead).toList();
      if (dead.isEmpty) continue;
      next = next.withPlayer(p.copyWith(
        arena: p.arena.where((c) => !c.isDead).toList(),
        ruins: [...p.ruins, ...dead],
      ));
    }
    return next;
  }
}
