import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  test('projection decodes the viewer hand and redacted opponent hand', () {
    final projection = PvpProjection.fromJson({
      'version': 1,
      'activePlayer': 'p1',
      'phase': 'main1',
      'turnNumber': 2,
      'winner': null,
      'chainCount': 0,
      'stage': 'main',
      'priority': 'p1',
      'pendingAttackers': const [],
      'revision': 7,
      'players': {
        'p1': {
          'id': 'p1',
          'health': 25,
          'hand': [
            {
              'instanceId': 11,
              'cardId': 'sproutling',
              'name': 'Sproutling',
              'type': 'unit',
              'subtype': '',
              'dominions': ['verdance'],
              'costDominion': const {},
              'costGeneric': 1,
              'might': 1,
              'guard': 1,
              'keywords': const [],
              'aegisValue': 0,
              'exerted': false,
              'damage': 0,
              'plusCounters': 0,
              'summonedThisTurn': false,
            },
          ],
          'handCount': 1,
          'deckCount': 35,
          'arena': const [],
          'ruins': const [],
          'ruinsCount': 0,
          'voidCount': 0,
          'aetherPool': const {},
          'playedWellspringThisTurn': false,
          'usedAttuneThisTurn': false,
          'viewer': 'p1',
        },
        'p2': {
          'id': 'p2',
          'health': 25,
          'hand': const [],
          'handCount': 6,
          'deckCount': 34,
          'arena': const [],
          'ruins': const [],
          'ruinsCount': 0,
          'voidCount': 0,
          'aetherPool': const {},
          'playedWellspringThisTurn': false,
          'usedAttuneThisTurn': false,
          'viewer': 'p1',
        },
      },
    });

    expect(projection.revision, 7);
    expect(projection.stage, PvpStage.main);
    expect(projection.self.hand.single.cardId, 'sproutling');
    expect(projection.opponent.hand, isEmpty);
    expect(projection.opponent.handCount, 6);
    expect(projection.opponent.deckCount, 34);
  });

  test('command envelope serializes the server intent', () {
    const command = PvpCommand(
      type: PvpCommandType.playUnit,
      idempotencyKey: '00000000-0000-4000-8000-000000000001',
      revision: 12,
      payload: {'instanceId': 44},
    );

    expect(command.toJson(), {
      'type': 'playUnit',
      'idempotencyKey': '00000000-0000-4000-8000-000000000001',
      'revision': 12,
      'payload': {'instanceId': 44},
    });
  });
}
