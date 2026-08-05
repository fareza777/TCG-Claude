import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_pvp_server/src/in_memory_pvp_repository.dart';
import 'package:shardfall_pvp_server/src/match_service.dart';
import 'package:shardfall_pvp_server/src/pvp_repository.dart';
import 'package:test/test.dart';

CardDef _unit(String id) => CardDef(
      id: id,
      name: 'Unit $id',
      dominions: const [Dominion.verdance],
      type: CardType.unit,
      costGeneric: 0,
      might: 1,
      guard: 1,
    );

CardDef _wellspring(String id) => CardDef(
      id: id,
      name: 'Wellspring $id',
      dominions: const [Dominion.verdance],
      type: CardType.wellspring,
    );

List<CardDef> _deck(String p) => [
      for (var i = 0; i < 16; i++) _wellspring('$p-w$i'),
      for (var i = 0; i < 24; i++) _unit('$p-u$i'),
    ];

Future<PersistedMatch> _seed(
  InMemoryPvpRepository repo, {
  required DateTime? deadline,
}) async {
  final session = PvpEngine.create(deckP1: _deck('a'), deckP2: _deck('b'), seed: 5);
  final match = PersistedMatch(
    id: 'm1',
    playerOneId: 'alice',
    playerTwoId: 'bob',
    status: 'active',
    engineVersion: 'v1',
    rulesetVersion: 'v1',
    session: session,
    turnDeadline: deadline,
  );
  await repo.initializeMatch(match);
  return match;
}

void main() {
  test('a decision left past its deadline is forfeited by the server', () async {
    // The whole point of the clock: an opponent who stalls must not be able to
    // hold the match hostage. Neither client is asked for permission.
    final repo = InMemoryPvpRepository();
    await _seed(repo, deadline: DateTime.now().toUtc().subtract(
      const Duration(minutes: 5),
    ));
    final service = MatchService(repository: repo);

    // Bob merely says hello; that is enough to run Alice's expired clock.
    final response = await service.command(
      matchId: 'm1',
      actorUserId: 'bob',
      command: const PvpCommand(
        type: PvpCommandType.heartbeat,
        idempotencyKey: 'hb',
        revision: 0,
      ),
    );

    expect(
      response.events.any((e) => e['type'] == 'turn_clock_expired'),
      isTrue,
      reason: 'the expiry has to be visible to both players',
    );
    final after = await repo.getMatch('m1');
    expect(after!.session.stage, isNot(PvpStage.waitingForReady),
        reason: 'the window moved on without the stalling player');
  });

  test('a decision still inside its deadline is left alone', () async {
    final repo = InMemoryPvpRepository();
    await _seed(repo, deadline: DateTime.now().toUtc().add(
      const Duration(minutes: 5),
    ));
    final service = MatchService(repository: repo);

    final response = await service.command(
      matchId: 'm1',
      actorUserId: 'bob',
      command: const PvpCommand(
        type: PvpCommandType.heartbeat,
        idempotencyKey: 'hb',
        revision: 0,
      ),
    );

    expect(response.events.any((e) => e['type'] == 'turn_clock_expired'), isFalse);
    final after = await repo.getMatch('m1');
    expect(after!.session.stage, PvpStage.waitingForReady);
  });

  test('every committed state carries the next deadline', () async {
    final repo = InMemoryPvpRepository();
    await _seed(repo, deadline: null);
    final service = MatchService(repository: repo);

    await service.command(
      matchId: 'm1',
      actorUserId: 'alice',
      command: const PvpCommand(
        type: PvpCommandType.ready,
        idempotencyKey: 'r1',
        revision: 0,
      ),
    );

    final after = await repo.getMatch('m1');
    expect(after!.turnDeadline, isNotNull,
        reason: 'without this the next window would never expire');
    expect(after.turnDeadline!.isAfter(DateTime.now().toUtc()), isTrue);
  });
}
