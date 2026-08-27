import 'package:shardfall_engine/shardfall_engine.dart';

/// What the player is being asked to do right now.
enum CoachStep {
  /// Aether is the resource, and a Wellspring is how you get it.
  playWellspring,

  /// Spend the Aether on a body.
  playUnit,

  /// Units cannot attack the turn they arrive, so the turn has to pass.
  endTurn,

  /// Swing with what survived.
  attack,

  /// Nothing left to teach; play it out.
  free,
}

/// One instruction: what to do, and why it matters.
class CoachPrompt {
  final String title;
  final String body;

  const CoachPrompt(this.title, this.body);
}

/// Walks a first-time player through one real battle.
///
/// The old tutorial was a slideshow. Nobody learns a card game by reading
/// about it — they learn by playing a Wellspring and watching an Aether appear.
/// So this coaches an actual duel rather than describing one.
///
/// Deliberately state-driven, not script-driven: each step is a question about
/// the board, so a player who does things out of order, or who works it out
/// early, is never told to do something they have already done.
class TutorialCoach {
  CoachStep step = CoachStep.playWellspring;

  /// Whether the player has ever ended a turn, which is the only way to tell
  /// "has not passed yet" from "passed and it came back around".
  bool _passedOnce = false;

  static const _prompts = <CoachStep, CoachPrompt>{
    CoachStep.playWellspring: CoachPrompt(
      'Play a Wellspring',
      'Wellsprings are your Aether — the resource everything else costs. '
          'You may play one each turn. Tap one in your hand.',
    ),
    CoachStep.playUnit: CoachPrompt(
      'Summon a unit',
      'Now spend that Aether. Tap a unit whose cost your Aether can cover.',
    ),
    CoachStep.endTurn: CoachPrompt(
      'End your turn',
      'A unit cannot attack the turn it arrives — it needs a turn to settle. '
          'End your turn and it will be ready.',
    ),
    CoachStep.attack: CoachPrompt(
      'Attack',
      'Your unit is ready. Send it at your opponent, then confirm the attack.',
    ),
    CoachStep.free: CoachPrompt(
      'You have the idea',
      'Wellspring, summon, attack. Finish this one on your own — the rest is '
          'just cards.',
    ),
  };

  CoachPrompt get prompt => _prompts[step]!;

  bool get isComplete => step == CoachStep.free;

  /// Re-reads the board and moves the instruction forward if it has been
  /// satisfied. Safe to call on every frame.
  void observe(GameState state, PlayerId human) {
    final me = state.player(human);

    final hasWellspring =
        me.arena.any((c) => c.def.type == CardType.wellspring) ||
            me.aetherPool.values.any((v) => v > 0) ||
            me.playedWellspringThisTurn;
    final hasUnit = me.arena.any((c) => c.def.type == CardType.unit);
    final canAttack =
        me.arena.any((c) => c.def.type == CardType.unit && c.canAttack);

    if (state.activePlayer != human) _passedOnce = true;

    step = switch (true) {
      _ when !hasWellspring => CoachStep.playWellspring,
      _ when !hasUnit => CoachStep.playUnit,
      _ when canAttack => CoachStep.attack,
      _ when !_passedOnce => CoachStep.endTurn,
      // Passed a turn, has a board, nothing is ready to swing: the lesson has
      // landed and standing in the way now would only be noise.
      _ => CoachStep.free,
    };
  }
}
