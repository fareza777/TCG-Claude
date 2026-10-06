import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/arena/arena_draft.dart';
import 'package:shardfall/arena/arena_draft_screen.dart';
import 'package:shardfall/theme.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// The colour choice that opens an Arena run.
///
/// A run used to be offered three random pairs. It now offers single colours
/// as well, grouped under their own headings, because the two are different
/// trades (a smaller pool with Aether that never fails, against a wider pool
/// with two kinds to balance) and a player choosing between them should be
/// told so before they pay for the run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  // Tests draw text in Ahem, a font where every letter is one em wide, unless
  // told otherwise. That makes a 19-letter heading 323px at 17px and reports
  // overflows no phone would show. Cinzel is the font the colour names are set
  // in and it ships with the app, so it is loaded for real; the app's default
  // `serif` is a system font that cannot be, so a bundled serif stands in.
  setUpAll(() async {
    Future<void> load(String family, String asset) async {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    }

    await load('Cinzel', 'assets/fonts/Cinzel.ttf');
    await load('serif', 'assets/fonts/EBGaramond.ttf');
  });

  Future<void> pump(WidgetTester tester, double width,
      {double textScale = 1.0}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: ArenaDraftScreen(library: library),
      ),
    ));
    await tester.pump();
  }

  testWidgets('single colours and pairs sit under their own headings',
      (tester) async {
    await pump(tester, 400);

    expect(find.text('ONE COLOUR'), findsOneWidget);
    expect(find.text('TWO COLOURS'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right),
        findsNWidgets(ArenaDraft.monoOffers + ArenaDraft.pairOffers));
  });

  testWidgets('each heading says what the choice costs', (tester) async {
    await pump(tester, 400);

    // The trade-off, in words, before the player commits.
    expect(find.textContaining('smaller pool'), findsOneWidget);
    expect(find.textContaining('wider pool'), findsOneWidget);
  });

  testWidgets('a colour name is never cut off, at any phone width',
      (tester) async {
    // Truncation reads as a different colour, and the same screens lost their
    // titles to an ellipsis before. Not overflowing is the weaker claim; this
    // checks that every name sits wholly inside the screen.
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3]) {
        await pump(tester, width, textScale: scale);

        final names = find.descendant(
            of: find.byType(FittedBox), matching: find.byType(Text));
        expect(names, findsWidgets);

        for (final element in names.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(0),
              reason: 'width $width scale $scale: a name starts off-screen');
          expect(rect.right, lessThanOrEqualTo(width),
              reason: 'width $width scale $scale: a name runs off-screen');
        }
        expect(tester.takeException(), isNull,
            reason: 'width $width scale $scale overflowed');
      }
    }
  });

  testWidgets('choosing a single colour starts a draft in that colour',
      (tester) async {
    await pump(tester, 400);

    // Singles lead the list, so the first tile is one.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump();

    expect(find.text('0 / ${ArenaDraft.picks}'), findsOneWidget,
        reason: 'the draft should have begun');
    expect(find.text('ONE COLOUR'), findsNothing,
        reason: 'the colour choice should be gone');
    expect(tester.takeException(), isNull);
  });
}
