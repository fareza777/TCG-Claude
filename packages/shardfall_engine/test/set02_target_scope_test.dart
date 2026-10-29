import 'dart:io';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:test/test.dart';

void main() {
  final library = CardLibrary.fromJsonString(
      File('../../data/cards/set02.json').readAsStringSync());
  final body = library.card('SF002-010');
  CardInstance creature(int id, PlayerId owner) =>
      CardInstance(instanceId: id, def: body, owner: owner);
  GameState battlefield() => GameState(
      p1: PlayerState(id: PlayerId.p1, arena: [creature(1, PlayerId.p1)]),
      p2: PlayerState(id: PlayerId.p2,
          arena: [creature(2, PlayerId.p2), creature(3, PlayerId.p2)]),
      rngSeed: 7, nextInstanceId: 20);

  test('Return to the Nursery recalls the chosen enemy and leaves its ally', () {
    final source = CardInstance(instanceId: 9,
        def: library.card('SF002-021'), owner: PlayerId.p1);
    final after = EffectInterpreter.applyTrigger(
        battlefield(), source, source.def.effects.single,
        chosen: [EffectTarget.unit(2)]);
    expect(after.p2.arena.map((c) => c.instanceId), [3]);
    expect(after.p2.hand.map((c) => c.instanceId), [2]);
  });

  test('Ivory Debtwarden destroys one chosen enemy rather than the whole board', () {
    final source = CardInstance(instanceId: 9,
        def: library.card('SF002-165'), owner: PlayerId.p1);
    final after = EffectInterpreter.applyTrigger(
        battlefield(), source, source.def.effects.single,
        chosen: [EffectTarget.unit(2)]);
    expect(after.p2.arena.map((c) => c.instanceId), [3]);
    expect(after.p2.ruins.map((c) => c.instanceId), [2]);
  });

  test('Neris retains the deliberately plural return effect on her fulfilled Vow', () {
    final source = CardInstance(instanceId: 9,
        def: library.card('SF002-128'), owner: PlayerId.p1);
    final block = source.def.effects.singleWhere((b) => b['trigger'] == 'ON_VOW');
    final after = EffectInterpreter.applyTrigger(battlefield(), source, block);
    expect(after.p2.arena, isEmpty);
    expect(after.p2.hand.map((c) => c.instanceId), [2, 3]);
    expect(after.p1.arena.map((c) => c.instanceId), [1]);
  });

  test('printed rules identify actual targets without authoring null values', () {
    for (final card in library.byId.values) {
      expect(RegExp(r'\b(None|null|undefined)\b').hasMatch(card.text), isFalse,
          reason: card.id);
    }
    expect(library.card('SF002-165').text,
        'When this enters the Arena: Destroy target enemy unit.');
    expect(library.card('SF002-128').text, contains('each enemy unit'));
  });
}
