import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/card_render/card_widget.dart';
import 'package:shardfall/widgets/card_zoom.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  final library = CardLibrary.fromJsonStrings([
    File('assets/data/set01.json').readAsStringSync(),
    File('assets/data/set02.json').readAsStringSync(),
  ]);
  test('screen readers receive actual card names in both sets', () {
    for (final id in ['SF001-004', 'SF002-024', 'SF002-138']) {
      final def = library.card(id);
      final label = CardWidget(def: def).semanticLabel;
      expect(label, contains('When ${def.name} enters play'));
      expect(label, isNot(contains('{name}')));
    }
  });
  testWidgets('full zoom rules resolve names and explain new mechanics', (
    tester,
  ) async {
    for (final id in ['SF001-004', 'SF002-024', 'SF002-138']) {
      final def = library.card(id);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCardZoom(context, def),
              child: const Text('Inspect'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inspect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(def.text.replaceAll('{name}', def.name)), findsWidgets);
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((t) => (t.data ?? '').contains('{name}')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    }
    expect(keywordGlossary['Vow'], contains('still in play'));
    expect(keywordGlossary['Renew'], contains('second Main phase'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
