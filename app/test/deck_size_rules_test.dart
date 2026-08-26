import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/deckbuilder/deck_builder_screen.dart';

/// One definition of how big a deck is.
///
/// The deck builder saved 40 *or more* while PvP required exactly 40, so a
/// legal 41-card deck was silently missing from the PvP list and the player
/// was told no valid deck existed while looking straight at one. Nothing
/// failed; the two numbers had simply drifted.
void main() {
  test('the deck-size rules are sane', () {
    expect(DeckBuilderScreen.minDeck, lessThan(DeckBuilderScreen.maxDeck));
    expect(DeckBuilderScreen.maxWellspring,
        lessThan(DeckBuilderScreen.minDeck));
  });

  test('no screen hard-codes the deck size instead of sharing it', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('deckbuilder/deck_builder_screen.dart')) continue;

      final source = entity.readAsStringSync();
      // A length compared against a bare 40 is the exact shape of the bug.
      if (RegExp(r'\.length\s*[=<>!]=?\s*40\b').hasMatch(source) ||
          RegExp(r'40\s*[=<>!]=?\s*\w+\.length').hasMatch(source)) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use DeckBuilderScreen.minDeck so the rule cannot drift: '
            '${offenders.join(", ")}');
  });
}
