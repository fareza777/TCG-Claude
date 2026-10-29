import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall/story/narration.dart';

// Production gate, intentionally separate from behavior tests: these must
// pass after the offline art and narration jobs finish, before a release.
void main() {
  test('all 215 collectible cards and their runtime tokens have real art', () {
    final document =
        jsonDecode(File('assets/data/set02.json').readAsStringSync())
            as Map<String, dynamic>;
    final cards = document['cards'] as List<dynamic>;
    final cardIds = {for (final card in cards) card['id'] as String};
    final tokenIds = _tokenArtIds(cards).toSet();
    expect(cardIds, hasLength(215));
    expect(tokenIds, {
      'TOKEN-Sapling',
      'TOKEN-Cinder',
      'TOKEN-Lantern',
      'TOKEN-Echo',
    });
    _expectWebPAssets({...cardIds, ...tokenIds});
  });
  test('every expansion illustration ships as a real WebP', () {
    final assets = {
      for (final c in storyChapters.skip(5))
        for (final stage in c.stages)
          if (stage.beat != null) stage.beat!.artAsset,
    };
    _expectWebPAssets(assets);
  });
  test('every new spoken line ships as nonempty MP3 audio', () {
    final missing = <String>[];
    for (final clip in Narration.all().where(
      (c) => c.chapterId.startsWith('vow'),
    )) {
      final file = File(Narration.assetPath(clip.id));
      if (!file.existsSync()) {
        missing.add(clip.id);
        continue;
      }
      final b = file.readAsBytesSync();
      expect(b.length, greaterThan(512), reason: clip.id);
      expect(
        String.fromCharCodes(b.take(3)) == 'ID3' ||
            (b[0] == 255 && (b[1] & 224) == 224),
        isTrue,
        reason: clip.id,
      );
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Production voice missing (${missing.length}): ${missing.take(8).join(', ')}',
    );
  });
}

Iterable<String> _tokenArtIds(Object? value) sync* {
  if (value is Map) {
    if (value['op'] == 'CREATE_TOKEN') {
      final token = value['token'] as Map;
      yield 'TOKEN-${token['name']}';
    }
    for (final child in value.values) {
      yield* _tokenArtIds(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* _tokenArtIds(child);
    }
  }
}

void _expectWebPAssets(Iterable<String> ids) {
  final missing = <String>[];
  for (final id in ids) {
    final file = File('assets/art/$id.webp');
    if (!file.existsSync()) {
      missing.add(id);
      continue;
    }
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(512), reason: id);
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF', reason: id);
    expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WEBP', reason: id);
  }
  expect(
    missing,
    isEmpty,
    reason: 'Production art missing: ${missing.join(', ')}',
  );
}
