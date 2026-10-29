import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/pvp/pvp_game_state.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

PvpProjection _projection(Map<String, dynamic> card) {
  Map<String, dynamic> player(String id) => {
    'id': id,
    'viewer': 'p2',
    'health': 25,
    'hand': [],
    'handCount': 0,
    'deckCount': 20,
    'arena': id == 'p2' ? [card] : [],
  };
  return PvpProjection.fromJson({
    'version': 1,
    'activePlayer': 'p2',
    'phase': 'main1',
    'turnNumber': 3,
    'chainCount': 0,
    'stage': 'main',
    'priority': 'p2',
    'pendingAttackers': [],
    'revision': 2,
    'players': {'p1': player('p1'), 'p2': player('p2')},
  });
}

Map<String, dynamic> _card() => {
  'instanceId': 22,
  'cardId': 'TOKEN-Cinder',
  'name': 'Cinder',
  'type': 'unit',
  'dominions': ['pyre'],
  'might': 4,
  'guard': 5,
  'vowFulfilled': true,
  'tempMight': 2,
  'tempGuard': 3,
  'plusCounters': 1,
  'tempKeywords': ['intercept'],
  'tokenDefinition': {
    'id': 'TOKEN-Cinder',
    'name': 'Cinder',
    'dominion': ['pyre'],
    'type': 'unit',
    'subtype': 'Token',
    'might': 1,
    'guard': 1,
    'keywords': ['rush'],
    'text': '',
  },
};

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});
  test(
    'unknown summoned tokens retain definition, keywords, Vow and modifiers across swapped seats',
    () {
      final state = PvpGameState.fromProjection(
        _projection(_card()),
        emptyLibrary,
      );
      final token = state.p1.arena.single;
      expect(token.owner, PlayerId.p1);
      expect(token.def.subtype, 'Token');
      expect(token.def.keywords, contains(Keyword.rush));
      expect(token.keywords, contains(Keyword.intercept));
      expect(token.vowFulfilled, isTrue);
      expect(token.might, 4);
      expect(token.guard, 5);
    },
  );

  test(
    'old projections default to unfulfilled Vow and no temporary modifiers',
    () {
      final card = _card()
        ..remove('vowFulfilled')
        ..remove('tempMight')
        ..remove('tempGuard')
        ..remove('tempKeywords');
      final token = PvpGameState.fromProjection(
        _projection(card),
        emptyLibrary,
      ).p1.arena.single;
      expect(token.vowFulfilled, isFalse);
      expect(token.tempMight, 0);
      expect(token.tempKeywords, isEmpty);
    },
  );

  test('a remote embedded definition cannot replace a catalog definition', () {
    const unit = CardDef(
      id: 'SF002-001',
      name: 'Real card',
      dominions: [Dominion.verdance],
      type: CardType.unit,
      might: 2,
      guard: 3,
    );
    const library = CardLibrary(byId: {'SF002-001': unit}, starterDecks: {});
    final card = _card()..['cardId'] = unit.id;
    final result = PvpGameState.fromProjection(
      _projection(card),
      library,
    ).p1.arena.single;
    expect(result.def, same(unit));
  });
}
