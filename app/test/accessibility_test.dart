import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/card_render/card_widget.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// Cards are drawn, not written. Without a label they announce nothing, which
/// makes the whole game unusable with a screen reader — and made automated
/// testing far harder than it needed to be, since the widget tree exposed no
/// text at all.
void main() {
  CardWidget widgetFor(CardDef def, {bool faceDown = false, int damage = 0}) =>
      CardWidget(def: def, faceDown: faceDown, damage: damage);

  const beater = CardDef(
    id: 'T1',
    name: 'Thornhide Boar',
    dominions: [Dominion.verdance],
    type: CardType.unit,
    might: 3,
    guard: 2,
    keywords: {Keyword.rush},
    rarity: Rarity.uncommon,
    text: 'Charges the moment it arrives.',
  );

  test('a card announces its name, stats, keywords and rules text', () {
    final label = widgetFor(beater).semanticLabel;
    expect(label, contains('Thornhide Boar'));
    expect(label, contains('3 might'));
    expect(label, contains('2 guard'));
    expect(label, contains('rush'));
    expect(label, contains('Charges the moment it arrives.'));
  });

  test('damage is announced as remaining guard, not the printed number', () {
    // A player needs to know what the card is now, not what it was printed as.
    expect(widgetFor(beater, damage: 1).semanticLabel, contains('1 of 2 guard'));
  });

  test('a face-down card gives nothing away', () {
    final label = widgetFor(beater, faceDown: true).semanticLabel;
    expect(label, 'Face-down card');
    expect(label, isNot(contains('Thornhide')),
        reason: 'announcing a hidden card would leak the opponent\'s hand');
  });
}
