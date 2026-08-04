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
      might: 2,
      guard: 2,
    );

CardDef _wellspring(String id) => CardDef(
      id: id,
      name: 'Wellspring $id',
      dominions: const [Dominion.verdance],
      type: CardType.wellspring,
    );

List<CardDef> _deck(String prefix) => [
      for (var i = 0; i < 16; i++) _wellspring('$prefix-ws-$i'),
      for (var i = 0; i < 24; i++) _unit('$prefix-unit-$i'),
    ];

PersistedMatch _match() => PersistedMatch(
      id: 'match-1',
      playerOneId: 'user-1',
      playerTwoId: 'user-2',
      status: 'active',
      session: PvpEngine.create(
        deckP1: _deck('p1'),
        deckP2: _deck('p2'),
        seed: 123,
      ),
      engineVersion: 'engine-test',
      rulesetVersion: 'rules-test',
    );

PvpCommand _command(int revision, String key, PvpCommandType type) =>
    PvpCommand(
      type: type,
      idempotencyKey: key,
      revision: revision,
    );

void main() {
  late InMemoryPvpRepository repository;
  late MatchService service;

  setUp(() {
    repository = InMemoryPvpRepository();
    repository.putMatch(_match());
    service = MatchService(repository: repository);
  });

  test('accepted command persists revision, projection, and event', () async {
    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'ready-1', PvpCommandType.ready),
    );

    expect(response.accepted, isTrue);
    expect(response.duplicate, isFalse);
    expect(response.revision, 1);
    expect(response.projection['revision'], 1);
    expect(response.events, isNotEmpty);

    final persisted = await repository.getMatch('match-1');
    expect(persisted?.session.revision, 1);
    expect(persisted?.status, 'active');
  });

  test(
      'same idempotency key returns the first response without a second transition',
      () async {
    final command = _command(0, 'ready-duplicate', PvpCommandType.ready);
    final first = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: command,
    );
    final second = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: command,
    );

    expect(first.accepted, isTrue);
    expect(second.accepted, isTrue);
    expect(second.duplicate, isTrue);
    expect(second.revision, first.revision);
    expect(second.projection, first.projection);
    expect((await repository.getMatch('match-1'))?.session.revision, 1);
  });

  test('stale revision is rejected without changing persisted state', () async {
    final first = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'ready-stale-first', PvpCommandType.ready),
    );
    final stale = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'ready-stale-second', PvpCommandType.ready),
    );

    expect(first.accepted, isTrue);
    expect(stale.accepted, isFalse);
    expect(stale.errorCode, 'stale_revision');
    expect(stale.revision, 1);
    expect((await repository.getMatch('match-1'))?.session.revision, 1);
  });

  test('non-member cannot command or reconnect to a match', () async {
    final command = await service.command(
      matchId: 'match-1',
      actorUserId: 'intruder',
      command: _command(0, 'intruder', PvpCommandType.ready),
    );
    final reconnect = await service.reconnect(
      matchId: 'match-1',
      actorUserId: 'intruder',
    );

    expect(command.accepted, isFalse);
    expect(command.errorCode, 'not_a_player');
    expect(reconnect.errorCode, 'not_a_player');
    expect((await repository.getMatch('match-1'))?.session.revision, 0);
  });

  test('reconnect returns only the requesting player projection', () async {
    final response = await service.reconnect(
      matchId: 'match-1',
      actorUserId: 'user-2',
    );

    expect(response.errorCode, isNull);
    expect(response.revision, 0);
    final players = response.projection['players'] as Map<String, dynamic>;
    expect((players['p2'] as Map<String, dynamic>)['hand'], isNotEmpty);
    expect((players['p1'] as Map<String, dynamic>)['hand'], isEmpty);
  });

  test('concede finishes once and duplicate retry is harmless', () async {
    final command = _command(0, 'concede-once', PvpCommandType.concede);
    final first = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-2',
      command: command,
    );
    final retry = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-2',
      command: command,
    );

    expect(first.accepted, isTrue);
    expect(first.status, 'finished');
    expect(retry.duplicate, isTrue);
    expect((await repository.getMatch('match-1'))?.session.revision, 1);
  });
}
