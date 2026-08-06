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

CardLibrary _library() {
  final cards = [..._deck('p1'), ..._deck('p2')];
  return CardLibrary(
    byId: {for (final card in cards) card.id: card},
    starterDecks: const {},
  );
}

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

  test('end turn walks the phases in one command until the seat changes',
      () async {
    // The client used to send nextPhase, an empty attack declaration and
    // another nextPhase itself -- a full network round trip each. The
    // composite resolves the same engine steps inside one lock.
    var revision = 0;
    for (final user in const ['user-1', 'user-2', 'user-1', 'user-2']) {
      final response = await service.command(
        matchId: 'match-1',
        actorUserId: user,
        command: _command(revision, 'ready-$user-$revision', PvpCommandType.ready),
      );
      expect(response.accepted, isTrue);
      revision = response.revision;
    }
    expect(
      (await repository.getMatch('match-1'))?.session.stage,
      PvpStage.main,
    );

    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(revision, 'end-turn-1', PvpCommandType.endTurn),
    );

    expect(response.accepted, isTrue);
    expect(response.revision, greaterThan(revision),
        reason: 'several engine steps resolved inside the one command');
    final persisted = await repository.getMatch('match-1');
    expect(persisted?.session.game.activePlayer, PlayerId.p2);
    expect(
      response.events.where((e) => e['type'] == 'phase_changed'),
      isNotEmpty,
    );
  });

  test('end turn outside your own turn is refused, not walked', () async {
    var revision = 0;
    for (final user in const ['user-1', 'user-2', 'user-1', 'user-2']) {
      final response = await service.command(
        matchId: 'match-1',
        actorUserId: user,
        command: _command(revision, 'ready-$user-$revision', PvpCommandType.ready),
      );
      revision = response.revision;
    }

    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-2',
      command: _command(revision, 'end-turn-intruder', PvpCommandType.endTurn),
    );

    expect(response.accepted, isFalse);
    expect(response.errorCode, 'illegal_stage');
    expect((await repository.getMatch('match-1'))?.session.revision, revision);
  });

  test('a heartbeat stamps presence for the stale-match reaper', () async {
    // Without this, a match lasting longer than the reaper's window looked
    // abandoned with both players still at the table.
    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'heartbeat-1', PvpCommandType.heartbeat),
    );

    expect(response.accepted, isTrue);
    final persisted = await repository.getMatch('match-1');
    expect(persisted?.lastHeartbeatByUser['user-1'], isNotNull);
  });

  test('a heartbeat is never stale, even after the board moved', () async {
    // Presence ticks every 20 seconds and races real moves constantly. Every
    // race it lost used to surface a phantom "old match revision" error.
    final moved = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'ready-before-heartbeat', PvpCommandType.ready),
    );
    expect(moved.accepted, isTrue);
    expect(moved.revision, greaterThan(0));

    final heartbeat = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'heartbeat-after-move', PvpCommandType.heartbeat),
    );

    expect(heartbeat.accepted, isTrue);
  });

  test('stored projections carry the clock for realtime subscribers', () async {
    // Clients receive these projections pushed inside the realtime payload;
    // without the deadline their timer strip would go blank between commands.
    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'ready-clock', PvpCommandType.ready),
    );

    expect(response.accepted, isTrue);
    final persisted = await repository.getMatch('match-1');
    expect(persisted?.projectionsByUser['user-1']?['deadlineAt'], isNotNull);
    expect(persisted?.projectionsByUser['user-2']?['deadlineAt'], isNotNull);
  });

  test('a rejected command does not restart the decision clock', () async {
    // Resetting the deadline on a refusal would let a stalling player extend
    // their own window forever by spamming illegal moves.
    final before = await repository.getMatch('match-1');
    final response = await service.command(
      matchId: 'match-1',
      actorUserId: 'user-1',
      command: _command(0, 'illegal-1', PvpCommandType.declareAttackers),
    );

    expect(response.accepted, isFalse);
    final after = await repository.getMatch('match-1');
    expect(after?.turnDeadline, before?.turnDeadline);
  });

  test('initializes a queued match from validated deck IDs exactly once',
      () async {
    final repo = InMemoryPvpRepository();
    final initService = MatchService(
      repository: repo,
      cardLibrary: _library(),
    );
    final p1Ids = _deck('p1').map((card) => card.id).toList();
    final p2Ids = _deck('p2').map((card) => card.id).toList();

    final first = await initService.initialize(
      matchId: 'match-new',
      playerOneId: 'user-1',
      playerTwoId: 'user-2',
      deckP1Ids: p1Ids,
      deckP2Ids: p2Ids,
      seed: 99,
    );
    final second = await initService.initialize(
      matchId: 'match-new',
      playerOneId: 'user-1',
      playerTwoId: 'user-2',
      deckP1Ids: p1Ids,
      deckP2Ids: p2Ids,
      seed: 100,
    );

    expect(first, isTrue);
    expect(second, isTrue);
    final match = await repo.getMatch('match-new');
    expect(match?.session.stage, PvpStage.waitingForReady);
    expect(match?.session.game.rngSeed, 99);
    expect(match?.session.game.p1.hand, isNotEmpty);
  });
}
