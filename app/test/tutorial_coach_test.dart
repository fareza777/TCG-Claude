import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/tutorial/tutorial_coach.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// The coach's job is to never tell the player to do something they have
/// already done. A tutorial that insists on step two while you are standing in
/// step three is worse than no tutorial: it teaches you that the game is not
/// paying attention.
const _wellspring = CardDef(
  id: 'ws',
  name: 'Verdant Wellspring',
  dominions: [Dominion.verdance],
  type: CardType.wellspring,
);

const _unit = CardDef(
  id: 'u',
  name: 'Thorn Sentry',
  dominions: [Dominion.verdance],
  type: CardType.unit,
  might: 2,
  guard: 2,
);

CardInstance inPlay(int id, CardDef def, {bool exerted = false}) =>
    CardInstance(instanceId: id, def: def, owner: PlayerId.p1, exerted: exerted);

GameState board({
  List<CardInstance> arena = const [],
  Map<Dominion, int> aether = const {},
  bool playedWellspring = false,
  PlayerId active = PlayerId.p1,
}) =>
    GameState(
      p1: PlayerState(
        id: PlayerId.p1,
        arena: arena,
        aetherPool: aether,
        playedWellspringThisTurn: playedWellspring,
      ),
      p2: const PlayerState(id: PlayerId.p2),
      activePlayer: active,
      rngSeed: 0,
    );

void main() {
  test('opens by asking for a Wellspring', () {
    final coach = TutorialCoach();
    coach.observe(board(), PlayerId.p1);

    expect(coach.step, CoachStep.playWellspring);
    expect(coach.prompt.title, isNotEmpty);
  });

  test('moves on once Aether exists', () {
    final coach = TutorialCoach();
    coach.observe(
        board(arena: [inPlay(1, _wellspring)]), PlayerId.p1);

    expect(coach.step, CoachStep.playUnit);
  });

  test('counts Aether in the pool as a Wellspring played', () {
    // Attune puts a card down face-down as Aether without it being a
    // Wellspring card. A coach that only looked for the card type would insist
    // the player do something they had already done another way.
    final coach = TutorialCoach();
    coach.observe(
        board(aether: const {Dominion.verdance: 1}), PlayerId.p1);

    expect(coach.step, CoachStep.playUnit);
  });

  test('asks for a turn to pass while the unit is still settling', () {
    final coach = TutorialCoach();
    coach.observe(
      board(arena: [inPlay(1, _wellspring), inPlay(2, _unit, exerted: true)]),
      PlayerId.p1,
    );

    expect(coach.step, CoachStep.endTurn);
  });

  test('asks for the attack as soon as something can make one', () {
    final coach = TutorialCoach();
    coach.observe(
      board(arena: [inPlay(1, _wellspring), inPlay(2, _unit)]),
      PlayerId.p1,
    );

    expect(coach.step, CoachStep.attack);
  });

  test('stops coaching once the loop has been completed', () {
    final coach = TutorialCoach();
    // The turn passes to the opponent...
    coach.observe(
      board(
        arena: [inPlay(1, _wellspring), inPlay(2, _unit, exerted: true)],
        active: PlayerId.p2,
      ),
      PlayerId.p1,
    );
    // ...and comes back with nothing ready to swing.
    coach.observe(
      board(arena: [inPlay(1, _wellspring), inPlay(2, _unit, exerted: true)]),
      PlayerId.p1,
    );

    expect(coach.step, CoachStep.free);
    expect(coach.isComplete, isTrue);
  });

  test('never goes backwards into a step already satisfied', () {
    // A player who plays two Wellsprings and three units must not be dragged
    // back to "play a Wellspring" because a later frame looked different.
    final coach = TutorialCoach();
    final full = board(arena: [
      inPlay(1, _wellspring),
      inPlay(2, _wellspring),
      inPlay(3, _unit),
    ]);

    for (var i = 0; i < 5; i++) {
      coach.observe(full, PlayerId.p1);
      expect(coach.step, isNot(CoachStep.playWellspring));
      expect(coach.step, isNot(CoachStep.playUnit));
    }
  });

  test('every step has something to say', () {
    for (final step in CoachStep.values) {
      final coach = TutorialCoach()..step = step;
      expect(coach.prompt.title, isNotEmpty, reason: '$step has no title');
      expect(coach.prompt.body, isNotEmpty, reason: '$step has no body');
    }
  });
}
