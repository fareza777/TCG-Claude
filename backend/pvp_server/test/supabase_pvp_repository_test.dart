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
    final responses = <String, http.Response>{
      '/rest/v1/pvp_matches': http.Response(
        jsonEncode([
          {
            'id': match.id,
            'player_one_id': match.playerOneId,
            'player_two_id': match.playerTwoId,
            'status': match.status,
            'engine_version': match.engineVersion,
            'ruleset_version': match.rulesetVersion,
            'public_state': {},
            'revision': 0,
            'updated_at': '2026-08-04T00:00:00.000Z',
          },
        ]),
        200,
      ),
      '/rest/v1/pvp_match_runtime': http.Response(
        jsonEncode([
          {'engine_state': PvpCodec.encodeSession(match.session)},
        ]),
        200,
      ),
      '/rest/v1/pvp_match_players': http.Response(
        jsonEncode([
          {
            'user_id': match.playerOneId,
            'private_state': {'viewer': 'p1'},
          },
          {
            'user_id': match.playerTwoId,
            'private_state': {'viewer': 'p2'},
          },
        ]),
        200,
      ),
    };
    final client = MockClient((request) async {
      final response = responses[request.url.path];
      if (response == null) return http.Response('not found', 404);
      return response;
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
