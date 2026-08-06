import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shardfall_pvp_server/src/pvp_repository.dart';
import 'package:shardfall_pvp_server/src/supabase_pvp_repository.dart';
import 'package:test/test.dart';

CardLibrary _library() {
  final defs = <CardDef>[
    for (var i = 0; i < 16; i++)
      CardDef(
        id: 'ws-$i',
        name: 'Wellspring',
        dominions: const [Dominion.verdance],
        type: CardType.wellspring,
      ),
    for (var i = 0; i < 24; i++)
      CardDef(
        id: 'unit-$i',
        name: 'Unit',
        dominions: const [Dominion.verdance],
        type: CardType.unit,
        might: 2,
        guard: 2,
      ),
  ];
  return CardLibrary(
    byId: {for (final def in defs) def.id: def},
    starterDecks: const {},
  );
}

PersistedMatch _match() => PersistedMatch(
      id: 'match-supa',
      playerOneId: '11111111-1111-1111-1111-111111111111',
      playerTwoId: '22222222-2222-2222-2222-222222222222',
      status: 'active',
      engineVersion: 'engine-test',
      rulesetVersion: 'rules-test',
      session: PvpEngine.create(
        deckP1: [
          for (var i = 0; i < 16; i++) _library().card('ws-$i'),
          for (var i = 0; i < 24; i++) _library().card('unit-$i'),
        ],
        deckP2: [
          for (var i = 0; i < 16; i++) _library().card('ws-$i'),
          for (var i = 0; i < 24; i++) _library().card('unit-$i'),
        ],
        seed: 77,
      ),
      projectionsByUser: const {
        '11111111-1111-1111-1111-111111111111': {},
        '22222222-2222-2222-2222-222222222222': {},
      },
    );

void main() {
  test('loads a match, full runtime state, and private projections', () async {
    final match = _match();
    final client = MockClient((request) async {
      if (request.url.path != '/rest/v1/rpc/pvp_get_match') {
        return http.Response('not found', 404);
      }
      // The whole point of the RPC: one round trip carries everything the
      // three separate table reads used to.
      return http.Response(
        jsonEncode({
          'id': match.id,
          'playerOneId': match.playerOneId,
          'playerTwoId': match.playerTwoId,
          'status': match.status,
          'engineVersion': match.engineVersion,
          'rulesetVersion': match.rulesetVersion,
          'revision': 0,
          'updatedAt': '2026-08-04T00:00:00.000Z',
          'turnDeadline': null,
          'engineState': PvpCodec.encodeSession(match.session),
          'players': [
            {
              'userId': match.playerOneId,
              'privateState': {'viewer': 'p1'},
              'lastHeartbeatAt': null,
            },
            {
              'userId': match.playerTwoId,
              'privateState': {'viewer': 'p2'},
              'lastHeartbeatAt': null,
            },
          ],
        }),
        200,
      );
    });
    final repository = SupabasePvpRepository(
      baseUrl: 'https://example.supabase.co',
      serviceKey: 'service-secret',
      cardLibrary: _library(),
      client: client,
    );

    final loaded = await repository.getMatch(match.id);

    expect(loaded?.id, match.id);
    expect(loaded?.session.game.rngSeed, 77);
    expect(loaded?.projectionsByUser[match.playerOneId]?['viewer'], 'p1');
  });

  test('the commit carries the turn deadline inside the transaction', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"matchId": "match-supa"}', 200);
    });
    final match = _match();
    final repository = SupabasePvpRepository(
      baseUrl: 'https://example.supabase.co',
      serviceKey: 'service-secret',
      cardLibrary: _library(),
      client: client,
    );
    final deadline = DateTime.utc(2026, 8, 6, 12);

    await repository.commitTransition(
      before: match,
      after: match.copyWith(turnDeadline: deadline),
      command: PvpCommandRecord(
        matchId: match.id,
        actorUserId: match.playerOneId,
        idempotencyKey: 'test-idempotency-key',
        commandType: PvpCommandType.nextPhase,
        result: 'accepted',
        response: PvpCommandResponse(
          matchId: match.id,
          accepted: true,
          duplicate: false,
          revision: 1,
          status: 'active',
          projection: const {},
          events: const [],
        ),
      ),
      events: const [],
    );

    expect(captured.url.path, '/rest/v1/rpc/pvp_commit_transition');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_turn_deadline'], deadline.toIso8601String());
  });

  test('initialization uses the service RPC and never puts the key in the body',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{}', 200);
    });
    final match = _match();
    final repository = SupabasePvpRepository(
      baseUrl: 'https://example.supabase.co',
      serviceKey: 'service-secret',
      cardLibrary: _library(),
      client: client,
    );

    await repository.initializeMatch(match);

    expect(captured.url.path, '/rest/v1/rpc/pvp_initialize_match');
    expect(captured.headers['apikey'], 'service-secret');
    expect(captured.body, isNot(contains('service-secret')));
    expect(jsonDecode(captured.body)['p_match_id'], match.id);
  });
}
