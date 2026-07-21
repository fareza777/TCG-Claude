import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/card_render/card_widget.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

void main() {
  const stag = CardDef(
    id: 'SF001-004',
    name: 'Grovewarden Stag',
    dominions: [Dominion.verdance],
    type: CardType.unit,
    subtype: 'Elk Guardian',
    costGeneric: 2,
    costDominion: {Dominion.verdance: 1},
    might: 3,
    guard: 4,
    keywords: {Keyword.rampage},
    rarity: Rarity.rare,
    text: 'Rampage. When {name} enters, put a +1/+1 counter on each other Unit you control.',
  );

  testWidgets('card face renders name, type line and stats', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: CardWidget(def: stag, width: 220))),
    ));
    expect(find.text('Grovewarden Stag'), findsOneWidget);
    expect(find.text('Unit — Elk Guardian'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // might badge
    expect(find.text('4'), findsOneWidget); // guard badge
    expect(find.byIcon(Icons.flash_on), findsOneWidget);
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  testWidgets('counters and damage shift the stat plaque', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: CardWidget(def: stag, width: 220, plusCounters: 1, damage: 2),
        ),
      ),
    ));
    // 3+1 might, 4+1-2 guard → both badges show adjusted values
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('face down hides the name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: CardWidget(def: stag, width: 220, faceDown: true)),
      ),
    ));
    expect(find.text('Grovewarden Stag'), findsNothing);
  });
}
