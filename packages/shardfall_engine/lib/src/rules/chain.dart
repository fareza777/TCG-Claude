import '../effects/interpreter.dart';
import '../model/enums.dart';
import '../model/game_state.dart';
import 'game.dart';

/// The Chain: SHARDFALL's response system (LIFO spell/ability queue).
///
/// Flow:
/// 1. A spell is cast → [push] adds it to the chain (cost already paid).
/// 2. Opponent gets priority: they may push a Rite in response, or pass.
/// 3. When both players pass consecutively, [resolveTop] pops and applies
///    the top item. Priority reopens after each resolution.
/// 4. Chain empty → the game continues in the current phase.
class Chain {
  /// Cast a spell from hand onto the chain. Pays the cost immediately.
  /// Rituals are only legal in the caster's own main phase on an empty chain.
  static GameState cast(
    GameState s,
    PlayerId caster,
    int instanceId, {
    List<EffectTarget> targets = const [],
  }) {
    final p = s.player(caster);
    final card = p.hand.firstWhere((c) => c.instanceId == instanceId);
    final type = card.def.type;
    if (type != CardType.rite && type != CardType.ritual) {
      throw StateError('${card.def.name} is not a spell');
    }
    if (type == CardType.ritual) {
      final ownMain = s.activePlayer == caster &&
          (s.phase == Phase.main1 || s.phase == Phase.main2);
      if (!ownMain || s.chain.isNotEmpty) {
        throw StateError('Rituals require your main phase and an empty chain');
      }
    }
    final poolAfter = Game.payCost(card.def, p.aetherPool);

    final uncounterable = card.def.effects.any((block) =>
        (block['effects'] as List?)
            ?.any((e) => (e as Map)['op'] == 'UNCOUNTERABLE') ??
        false);

    final onCast = card.def.effects.firstWhere(
      (block) =>
          block['trigger'] == 'ON_CAST' || !block.containsKey('trigger'),
      orElse: () => {'effects': const []},
    );

    return s
        .withPlayer(p.copyWith(
          hand: [...p.hand]..removeWhere((c) => c.instanceId == instanceId),
          aetherPool: poolAfter,
        ))
        .copyWith(chain: [
      ...s.chain,
      ChainItem(
        source: card,
        controller: caster,
        triggerBlock: Map<String, dynamic>.from(onCast),
        chosenTargets: targets,
        uncounterable: uncounterable,
      ),
    ]);
  }

  /// Counter the chain item at [chainIndex] (top = last). Fails on
  /// uncounterable spells. `unlessPay`: opponent may pay to refuse — the
  /// caller resolves that decision and passes [opponentPaid].
  static GameState counter(
    GameState s,
    int chainIndex, {
    bool opponentPaid = false,
  }) {
    final item = s.chain[chainIndex];
    if (item.uncounterable) {
      throw StateError('${item.source.def.name} cannot be countered');
    }
    if (opponentPaid) return s; // counter fizzles
    final chain = [...s.chain];
    chain[chainIndex] = item.copyWith(countered: true);
    return s.copyWith(chain: chain);
  }

  /// Resolve the top item: apply its effects (unless countered), then move
  /// the spell card to its owner's Ruins.
  static GameState resolveTop(GameState s) {
    if (s.chain.isEmpty) throw StateError('Chain is empty');
    final item = s.chain.last;
    var next = s.copyWith(chain: [...s.chain]..removeLast());

    if (!item.countered) {
      next = EffectInterpreter.applyTrigger(
        next,
        item.source,
        item.triggerBlock,
        chosen: [for (final t in item.chosenTargets) t as EffectTarget],
      );
    }

    final owner = next.player(item.source.owner);
    next = next.withPlayer(
      owner.copyWith(ruins: [...owner.ruins, item.source]),
    );
    return next;
  }

  /// Resolve the whole chain (used when both players keep passing).
  static GameState resolveAll(GameState s) {
    var next = s;
    while (next.chain.isNotEmpty && next.winner == null) {
      next = resolveTop(next);
    }
    return next;
  }
}
