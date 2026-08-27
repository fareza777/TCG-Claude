import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/services/haptics.dart';

/// A feedback setting that does not actually stop the feedback is worse than
/// no setting: the player turns it off, the phone keeps buzzing, and they
/// conclude the game ignores them. So the switch is tested, not just written.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String? ?? 'default');
      }
      return null;
    });
    Haptics.enabled = true;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Haptics.enabled = true;
  });

  test('each level reaches the platform', () async {
    Haptics.select();
    Haptics.commit();
    Haptics.strike();
    Haptics.blow();
    await Future<void>.delayed(Duration.zero);

    expect(calls, hasLength(4));
    expect(calls.toSet(), hasLength(4),
        reason: 'four levels the hand cannot tell apart are one level');
  });

  test('turning it off silences every level', () async {
    Haptics.enabled = false;
    Haptics.select();
    Haptics.commit();
    Haptics.strike();
    Haptics.blow();
    await Future<void>.delayed(Duration.zero);

    expect(calls, isEmpty);
  });
}
