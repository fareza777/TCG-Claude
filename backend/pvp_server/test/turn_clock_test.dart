import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_pvp_server/src/turn_clock.dart';
import 'package:test/test.dart';

PvpSession _session({
  required PvpStage stage,
  PlayerId active = PlayerId.p1,
  PlayerId priority = PlayerId.p1,
  Map<PlayerId, bool> ready = const {PlayerId.p1: true, PlayerId.p2: true},
}) =>
    PvpSession(
      game: GameState(
        p1: const PlayerState(id: PlayerId.p1),
        p2: const PlayerState(id: PlayerId.p2),
        activePlayer: active,
        rngSeed: 1,
      ),
      stage: stage,
      ready: ready,
      mulliganUsed: const {PlayerId.p1: false, PlayerId.p2: false},
      priority: priority,
      passCount: 0,
      resumeStage: PvpStage.main,
      pendingAttackers: const [],
      revision: 0,
    );

void main() {
  test('every live stage has a budget and a forfeit action', () {
    for (final stage in PvpStage.values) {
      if (stage == PvpStage.finished) continue;
      expect(TurnClock.budgetFor(stage), greaterThan(Duration.zero),
          reason: '$stage must be bounded, or a staller can wait forever');
      expect(TurnClock.forfeitActionFor(stage), isNotNull, reason: '$stage');
    }
  });

  test('a finished match has no clock', () {
    expect(TurnClock.deadlineFor(_session(stage: PvpStage.finished),
        DateTime.utc(2026)), isNull);
    expect(TurnClock.forfeitActionFor(PvpStage.finished), isNull);
  });

  test('the clock is owed by whoever is holding things up', () {
    expect(
      TurnClock.owedBy(_session(stage: PvpStage.main, active: PlayerId.p2)),
      [PlayerId.p2],
    );
    // The defender declares blocks, not the attacker.
    expect(
      TurnClock.owedBy(
          _session(stage: PvpStage.blockDeclaration, active: PlayerId.p1)),
      [PlayerId.p2],
    );
    expect(
      TurnClock.owedBy(_session(
          stage: PvpStage.chainPriority, priority: PlayerId.p2)),
      [PlayerId.p2],
    );
  });

  test('the ready window can be owed by both players at once', () {
    final owed = TurnClock.owedBy(_session(
      stage: PvpStage.waitingForReady,
      ready: const {PlayerId.p1: false, PlayerId.p2: false},
    ));
    expect(owed, [PlayerId.p1, PlayerId.p2]);
  });

  test('running out of time never attacks or blocks for the player', () {
    expect(
      TurnClock.forfeitPayloadFor(PvpStage.attackDeclaration),
      {'attackerIds': <int>[]},
    );
    expect(
      TurnClock.forfeitPayloadFor(PvpStage.blockDeclaration),
      {'blocks': <Map<String, dynamic>>[]},
    );
  });

  test('the deadline carries a grace margin for the round trip', () {
    final now = DateTime.utc(2026, 1, 1);
    final deadline = TurnClock.deadlineFor(_session(stage: PvpStage.main), now)!;
    expect(
      deadline.difference(now),
      TurnClock.main + TurnClock.grace,
      reason: 'answering just in time must not lose to network latency',
    );
  });
}
