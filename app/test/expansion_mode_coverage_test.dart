import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/arena/arena_draft.dart';
import 'package:shardfall/gauntlet/daily_gauntlet.dart';
import 'package:shardfall/pvp/pvp_game_state.dart';
import 'package:shardfall/pvp/pvp_models.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  final expansion = library.byId.keys
      .where((id) => id.startsWith('SF002-'))
      .toSet();
  test(
    'all 215 catalog definitions survive the real server/client PvP path',
    () {
      final base = PvpEngine.create(
        deckP1: BattleDecks.build(library, 'VERDANCE', seed: 19),
        deckP2: BattleDecks.build(library, 'GLOOM', seed: 29),
        seed: 3,
      );
      for (final id in expansion) {
        final def = library.card(id);
        final game = base.game.withPlayer(
          base.game.p1.copyWith(
            hand: [
              CardInstance(
                instanceId: 101,
                def: def,
                owner: PlayerId.p1,
                vowFulfilled: true,
              ),
            ],
          ),
        );
        final session = base.copyWith(game: game);
        final restored = PvpCodec.decodeSession(
          PvpCodec.encodeSession(session),
          library,
        );
        expect(restored.game.p1.hand.single.def, same(def));
        expect(restored.game.p1.hand.single.vowFulfilled, isTrue);
        final projection = PvpProjection.fromJson(
          PvpCodec.encodeProjection(restored, PlayerId.p1),
        );
        final client = PvpGameState.fromProjection(projection, library);
        expect(client.p1.hand.single.def, same(def));
        expect(client.p1.hand.single.def.effects, def.effects);
        expect(client.p1.hand.single.def.text, def.text);
      }
    },
  );
  test(
    'Daily loan decks can contain every expansion card including 7/8-cost finishers and basics',
    () {
      final seen = <String>{};
      for (var i = 0; i < 3000; i++) {
        final day = DailyGauntlet.build(
          library,
          DailyGauntlet.idFor(DateTime.utc(2026, 1, 1).add(Duration(days: i))),
        );
        seen.addAll(day.deck.keys);
      }
      expect(expansion.difference(seen), isEmpty);
    },
  );
  test(
    'Arena offers and finished decks make every expansion card available',
    () {
      final seen = <String>{};
      for (final faction in Dominion.values.where(
        (d) => d != Dominion.neutral,
      )) {
        for (var seed = 0; seed < 300; seed++) {
          final draft = ArenaDraft(
            library: library,
            dominions: [faction],
            rng: Random(seed),
          );
          while (!draft.isComplete) {
            seen.addAll(draft.offer.map((c) => c.id));
            draft.take(draft.offer.first);
          }
          seen.addAll(draft.buildDeck().map((c) => c.id));
        }
      }
      expect(expansion.difference(seen), isEmpty);
    },
  );
}
