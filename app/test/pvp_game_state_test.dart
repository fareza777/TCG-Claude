import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall/pvp/pvp_game_state.dart';
import 'package:shardfall/pvp/pvp_models.dart';

const _library = CardLibrary(byId: {}, starterDecks: {});

Map<String, dynamic> _card(int instanceId, {String cardId = 'SF001-001'}) => {
      'instanceId': instanceId,
      'cardId': cardId,
      'name': 'Card $instanceId',
      'type': 'unit',
      'subtype': '',
      'dominions': const ['verdance'],
      'might': 2,
      'guard': 2,
      'exerted': false,
      'damage': 0,
      'plusCounters': 0,
      'summonedThisTurn': false,
    };

Map<String, dynamic> _player(
  String id, {
  int health = 25,
  List<Map<String, dynamic>> hand = const [],
  int handCount = 0,
  List<Map<String, dynamic>> arena = const [],
  int deckCount = 30,
}) =>
    {
      'id': id,
      'health': health,
      'hand': hand,
      'handCount': handCount,
      'deckCount': deckCount,
      'arena': arena,
      'ruinsCount': 0,
      'voidCount': 0,
      'aetherPool': const {},
      'playedWellspringThisTurn': false,
      'usedAttuneThisTurn': false,
    };

PvpProjection _projection({
  required String viewer,
  String activePlayer = 'p1',
  String? winner,
  Map<String, dynamic>? p1,
  Map<String, dynamic>? p2,
}) =>
    PvpProjection.fromJson({
      'version': 1,
      'activePlayer': activePlayer,
      'phase': 'main1',
      'turnNumber': 3,
      'winner': winner,
      'chainCount': 0,
      'stage': 'main',
      'priority': activePlayer,
      'pendingAttackers': const [],
      'revision': 5,
      'players': {
        // The parser reads the viewer from inside a player entry.
        'p1': {...p1 ?? _player('p1'), 'viewer': viewer},
        'p2': {...p2 ?? _player('p2'), 'viewer': viewer},
      },
    });

void main() {
  test('the viewer is always mapped to p1', () {
    // The duel screen is written around human == p1, so a player seated as p2
    // must still be drawn as p1 or every panel would be on the wrong side.
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p2',
        p1: _player('p1', health: 11),
        p2: _player('p2', health: 22),
      ),
      _library,
    );

    expect(state.p1.health, 22, reason: 'the viewer (p2) becomes p1');
    expect(state.p2.health, 11);
  });

  test('a swapped seat swaps the active player with it', () {
    // p1 is active on the server; from p2's chair that must read as "opponent".
    final state = PvpGameState.fromProjection(
      _projection(viewer: 'p2', activePlayer: 'p1'),
      _library,
    );

    expect(state.activePlayer, PlayerId.p2);
  });

  test('a swapped seat swaps the winner with it', () {
    final asWinner = PvpGameState.fromProjection(
      _projection(viewer: 'p2', winner: 'p2'),
      _library,
    );
    final asLoser = PvpGameState.fromProjection(
      _projection(viewer: 'p2', winner: 'p1'),
      _library,
    );

    expect(asWinner.winner, PlayerId.p1, reason: 'the viewer won');
    expect(asLoser.winner, PlayerId.p2);
  });

  test('an unswapped seat is left alone', () {
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p1',
        activePlayer: 'p2',
        p1: _player('p1', health: 11),
        p2: _player('p2', health: 22),
      ),
      _library,
    );

    expect(state.p1.health, 11);
    expect(state.activePlayer, PlayerId.p2);
  });

  test('the opponent hand is filled with face-down placeholders', () {
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p1',
        p1: _player('p1', hand: [_card(1), _card(2)], handCount: 2),
        p2: _player('p2', handCount: 4),
      ),
      _library,
    );

    expect(state.p1.hand.length, 2);
    expect(state.p1.hand.map((c) => c.instanceId), [1, 2]);

    // The server never sends the opponent's cards, only how many there are.
    expect(state.p2.hand.length, 4);
    expect(
      state.p2.hand.every((c) => c.def == PvpGameState.hiddenCard),
      isTrue,
      reason: 'a hidden card must never carry a real definition',
    );
  });

  test('placeholder ids cannot collide with real card ids', () {
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p1',
        p1: _player('p1', hand: [_card(7)], handCount: 1, deckCount: 5),
        p2: _player('p2', handCount: 3, deckCount: 5),
      ),
      _library,
    );

    final real = {7};
    final placeholders = [
      ...state.p1.deck,
      ...state.p2.deck,
      ...state.p2.hand,
    ].map((c) => c.instanceId).toSet();

    expect(placeholders.intersection(real), isEmpty);
    expect(placeholders.length, 5 + 5 + 3, reason: 'ids stay unique');
  });

  test('a card missing from this build still renders', () {
    // A set update can reach the server before it reaches the player's app.
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p1',
        p1: _player(
          'p1',
          hand: [_card(3, cardId: 'SF002-999')],
          handCount: 1,
        ),
      ),
      _library,
    );

    expect(state.p1.hand.single.def.id, 'SF002-999');
    expect(state.p1.hand.single.def.name, 'Card 3');
  });

  test('board state survives the mapping', () {
    final state = PvpGameState.fromProjection(
      _projection(
        viewer: 'p1',
        p1: _player('p1', arena: [_card(10)], deckCount: 12),
      ),
      _library,
    );

    expect(state.p1.arena.single.instanceId, 10);
    expect(state.p1.deck.length, 12);
    expect(state.turnNumber, 3);
    expect(state.phase, Phase.main1);
  });
}
