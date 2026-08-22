// Prints every spoken line as JSON for the voice-over pipeline.
//
// Run from app/:  dart run tool/dump_narration.dart > ../tools/voice_pipeline/narration.json
//
// This reads the same story data the game does, so the clip ids it emits are
// exactly the ones the player will look for at runtime.
import 'dart:convert';

import 'package:shardfall/story/narration.dart';

void main() {
  final clips = Narration.all();
  final chars = clips.fold<int>(0, (sum, c) => sum + c.text.length);
  final out = {
    'count': clips.length,
    'characters': chars,
    'clips': [
      for (final c in clips)
        {
          'id': c.id,
          'chapter': c.chapterId,
          'voiceKey': c.voiceKey,
          'text': c.text,
        }
    ],
  };
  print(const JsonEncoder.withIndent('  ').convert(out));
}
