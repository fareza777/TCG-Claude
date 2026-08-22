import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/narration.dart';
import 'package:shardfall/story/story_data.dart';

/// Voice-over coverage.
///
/// Clip ids are positional, so inserting or reordering a line silently points
/// the player at a file that was never generated — the game would simply fall
/// silent on that line, which is the kind of gap nobody notices until a player
/// reports it. These tests fail instead.
void main() {
  final clips = Narration.all();

  test('every spoken line maps to a distinct clip id', () {
    final ids = clips.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(ids.length),
        reason: 'two lines share a clip id, so one would overwrite the other');
  });

  test('clip ids cover beats, briefings and victories', () {
    final slots = clips.map((c) => c.id.split('_')[2]).toSet();
    expect(slots, containsAll([
      Narration.slotBeat,
      Narration.slotPre,
      Narration.slotVictory,
    ]));
  });

  test('every line has a generated audio clip', () {
    final missing = <String>[];
    for (final clip in clips) {
      if (!File('assets/vo/${clip.id}.mp3').existsSync()) {
        missing.add('${clip.id}  [${clip.voiceKey}] '
            '"${clip.text.substring(0, clip.text.length.clamp(0, 45))}..."');
      }
    }
    expect(missing, isEmpty,
        reason: '${missing.length} of ${clips.length} lines have no audio.\n'
            'Regenerate with tools/voice_pipeline/generate_vo.js:\n'
            '${missing.take(10).join('\n')}');
  });

  test('no orphaned clips are shipping in the APK', () {
    final dir = Directory('assets/vo');
    if (!dir.existsSync()) return;
    final known = clips.map((c) => c.id).toSet();
    final orphans = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.mp3'))
        .map((n) => n.substring(0, n.length - 4))
        .where((id) => !known.contains(id))
        .toList();
    expect(orphans, isEmpty,
        reason: 'these clips no longer match any line and are dead weight in '
            'the download: ${orphans.take(10).join(", ")}');
  });

  test('the campaign still has the narration it was written with', () {
    // A blunt regression guard: if this number drops, lines were lost.
    expect(clips.length, greaterThanOrEqualTo(400));
    expect(storyChapters, hasLength(5));
  });
}
