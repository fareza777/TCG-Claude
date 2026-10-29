import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/story_scene.dart';
import 'package:shardfall/theme.dart';

void main() {
  tearDown(() => MotionPrefs.reduce = false);
  Widget scene({bool systemReduce = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: systemReduce),
      child: const SizedBox(
        width: 400,
        height: 300,
        child: StoryScene(
          artAsset: 'STORY-vow01-01',
          previousArtAsset: 'STORY-ch5-20',
        ),
      ),
    ),
  );
  testWidgets('new scene moves, crossfades and releases tickers on exit', (
    t,
  ) async {
    await t.pumpWidget(scene());
    final first = t
        .widget<Transform>(find.byKey(const ValueKey('story-scene-camera')))
        .transform;
    await t.pump(const Duration(seconds: 5));
    final later = t
        .widget<Transform>(find.byKey(const ValueKey('story-scene-camera')))
        .transform;
    expect(later.storage[0], greaterThan(first.storage[0]));
    expect(t.widget<Opacity>(find.byType(Opacity).last).opacity, 1);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 20));
    expect(t.takeException(), isNull);
    expect(t.binding.transientCallbackCount, 0);
  });
  testWidgets(
    'app and operating-system reduced motion remove camera movement',
    (t) async {
      for (final system in [false, true]) {
        MotionPrefs.reduce = !system;
        await t.pumpWidget(scene(systemReduce: system));
        await t.pump(const Duration(seconds: 5));
        final matrix = t
            .widget<Transform>(find.byKey(const ValueKey('story-scene-camera')))
            .transform;
        expect(matrix.storage[0], 1);
        expect(t.binding.transientCallbackCount, 0);
        await t.pumpWidget(const SizedBox());
      }
    },
  );
}
