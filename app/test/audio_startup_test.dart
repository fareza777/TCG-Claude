import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/services/audio_manager.dart';

class _CachedAudio extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => fileName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup completes while ambient playback waits for browser permission',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final playbackAllowed = Completer<void>();
      final playbackRequested = Completer<void>();
      final oldCache = AudioCache.instance;
      AudioCache.instance = _CachedAudio();
      for (final channel in [
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers.global/events',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (_) async => null,
        );
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async {
          final id = (call.arguments as Map)['playerId'];
          final events = 'xyz.luan/audioplayers/events/$id';
          if (call.method == 'create') {
            messenger.setMockMethodCallHandler(
              MethodChannel(events),
              (_) async => null,
            );
          }
          if (call.method == 'setSourceUrl') {
            // Simulate a prepared media file; only playback permission is pending.
            // ignore: deprecated_member_use
            await messenger.handlePlatformMessage(
              events,
              const StandardMethodCodec().encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
              (_) {},
            );
          }
          if (call.method == 'resume') {
            if (!playbackRequested.isCompleted) playbackRequested.complete();
            await playbackAllowed.future;
          }
          return null;
        },
      );
      var initialized = false;
      final manager = AudioManager.instance;
      final initialization = manager
          .init(music: true, sfx: false, voice: false)
          .then((_) => initialized = true);
      try {
        await playbackRequested.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          initialized,
          isTrue,
          reason: 'The menu must not wait for a browser audio gesture.',
        );
        expect(playbackAllowed.isCompleted, isFalse);
      } finally {
        playbackAllowed.complete();
        await initialization;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await manager.stopMusic();
        AudioCache.instance = oldCache;
      }
    },
  );
}
