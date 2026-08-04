import 'dart:convert';

import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_pvp_server/src/http_server.dart';
import 'package:shardfall_pvp_server/src/in_memory_pvp_repository.dart';
import 'package:shardfall_pvp_server/src/match_service.dart';
import 'package:shardfall_pvp_server/src/pvp_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

PersistedMatch _match() => PersistedMatch(
      id: 'match-http',
      playerOneId: 'user-1',
      playerTwoId: 'user-2',
      status: 'active',
      session: PvpEngine.create(
        deckP1: [
          for (var i = 0; i < 16; i++)
            CardDef(
              id: 'p1-ws-$i',
              name: 'Wellspring',
              dominions: const [Dominion.verdance],
              type: CardType.wellspring,
            ),
          for (var i = 0; i < 24; i++)
            CardDef(
              id: 'p1-u-$i',
              name: 'Unit',
              dominions: const [Dominion.verdance],
              type: CardType.unit,
              might: 2,
              guard: 2,
            ),
        ],
        deckP2: [
          for (var i = 0; i < 16; i++)
            CardDef(
              id: 'p2-ws-$i',
              name: 'Wellspring',
              dominions: const [Dominion.verdance],
              type: CardType.wellspring,
            ),
          for (var i = 0; i < 24; i++)
            CardDef(
              id: 'p2-u-$i',
              name: 'Unit',
              dominions: const [Dominion.verdance],
              type: CardType.unit,
              might: 2,
              guard: 2,
            ),
        ],
        seed: 5,
      ),
      engineVersion: 'engine-test',
      rulesetVersion: 'rules-test',
    );

CardLibrary _library() => CardLibrary(
      byId: {
        for (var i = 0; i < 16; i++)
          'p1-ws-$i': CardDef(
            id: 'p1-ws-$i',
            name: 'Wellspring',
            dominions: const [Dominion.verdance],
            type: CardType.wellspring,
          ),
        for (var i = 0; i < 24; i++)
          'p1-u-$i': CardDef(
            id: 'p1-u-$i',
            name: 'Unit',
            dominions: const [Dominion.verdance],
            type: CardType.unit,
            might: 2,
            guard: 2,
          ),
        for (var i = 0; i < 16; i++)
          'p2-ws-$i': CardDef(
            id: 'p2-ws-$i',
            name: 'Wellspring',
            dominions: const [Dominion.verdance],
            type: CardType.wellspring,
          ),
        for (var i = 0; i < 24; i++)
          'p2-u-$i': CardDef(
            id: 'p2-u-$i',
            name: 'Unit',
            dominions: const [Dominion.verdance],
            type: CardType.unit,
            might: 2,
            guard: 2,
          ),
      },
      starterDecks: const {},
    );

void main() {
  late PvpHttpServer server;

  setUp(() {
    final repository = InMemoryPvpRepository()..putMatch(_match());
    server = PvpHttpServer(
      service: MatchService(repository: repository, cardLibrary: _library()),
      cardLibrary: _library(),
      internalSecret: 'test-secret',
    );
  });

  test('health endpoint reports service versions without secrets', () async {
    final response = await server.handler(
      Request('GET', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, 200);
    final body = jsonDecode(await response.readAsString()) as Map;
    expect(body['ok'], isTrue);
    expect(body['service'], 'shardfall-pvp');
    expect(body.toString(), isNot(contains('test-secret')));
  });

  test('command endpoint rejects missing internal authentication', () async {
    final response = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/internal/v1/matches/match-http/commands'),
        body: jsonEncode({
          'actorUserId': 'user-1',
          'command': {
            'type': 'ready',
            'idempotencyKey': 'http-ready',
            'revision': 0,
            'payload': {},
          },
        }),
      ),
    );

    expect(response.statusCode, 401);
  });

  test('authenticated command endpoint returns player-safe JSON', () async {
    final response = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/internal/v1/matches/match-http/commands'),
        headers: {
          'content-type': 'application/json',
          'x-pvp-internal-secret': 'test-secret',
        },
        body: jsonEncode({
          'actorUserId': 'user-1',
          'command': {
            'type': 'ready',
            'idempotencyKey': 'http-ready',
            'revision': 0,
            'payload': {},
          },
        }),
      ),
    );

    expect(response.statusCode, 200);
    final body = jsonDecode(await response.readAsString()) as Map;
    expect(body['accepted'], isTrue);
    expect(body['projection']['revision'], 1);
    expect(body.toString(), isNot(contains('test-secret')));
  });

  test('authenticated initializer endpoint is idempotent', () async {
    final ids = [
      for (var i = 0; i < 16; i++) 'p1-ws-$i',
      for (var i = 0; i < 24; i++) 'p1-u-$i',
    ];
    final response = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/internal/v1/matches/match-http/initialize'),
        headers: {
          'content-type': 'application/json',
          'x-pvp-internal-secret': 'test-secret',
        },
        body: jsonEncode({
          'matchId': 'match-http',
          'players': [
            {'userId': 'user-1', 'seat': 'p1', 'deckSnapshot': ids},
            {'userId': 'user-2', 'seat': 'p2', 'deckSnapshot': ids},
          ],
        }),
      ),
    );

    expect(response.statusCode, 200);
    final body = jsonDecode(await response.readAsString()) as Map;
    expect(body['initialized'], isTrue);
  });
}
