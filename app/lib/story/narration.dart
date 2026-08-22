import 'story_data.dart';

/// One spoken line and the clip that voices it.
class NarrationClip {
  final String id;
  final String chapterId;
  final String speaker; // '' for narration
  final String text;

  const NarrationClip({
    required this.id,
    required this.chapterId,
    required this.speaker,
    required this.text,
  });

  String get voiceKey => speaker.isEmpty ? 'Narrator' : speaker;
}

/// Naming for the voice-over clips, shared by the generator and the player so
/// the two can never drift apart.
///
/// Ids are positional — chapter, stage, slot, line — rather than hashed, so a
/// missing clip points straight at the line that needs one. [narrationTest]
/// guards the mapping: if someone inserts a line without regenerating audio,
/// the suite fails instead of the game falling silent.
abstract final class Narration {
  /// Beat dialogue.
  static const slotBeat = 'b';

  /// The lines spoken on the battle briefing screen.
  static const slotPre = 'p';

  /// The lines spoken after a win.
  static const slotVictory = 'v';

  static String clipId(String chapterId, int stage, String slot, int line) =>
      '${chapterId}_${_pad(stage)}_${slot}_${_pad(line)}';

  static String assetPath(String id) => 'assets/vo/$id.mp3';

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// The chapter id used for the opening cinematic, which is narration too
  /// even though it lives outside the campaign chapters.
  static const introId = 'intro';

  /// The opening cinematic's script. It lives here rather than in the widget
  /// so the generator can read it without pulling in Flutter, and so the words
  /// on screen and the words in the audio cannot drift apart.
  static const introLines = <String>[
    'A thousand years ago, the star Vael hung whole in the night — and the world of Aethyr slept beneath its light.',
    'Then it shattered. Five burning Shards fell upon the world, and where each one struck, a Dominion woke.',
    'Where the emerald Shard fell, the forests of Sylvaris remembered how to move — and chose their wardens.',
    'Where the crimson Shard fell, the forges of Ashmar burned a thousand years without fuel.',
    'The cyan Shard sank beneath Meridine, into an archive of truths the tide would rather keep drowned.',
    'The golden Shard crowned the Concord of Dawn in borrowed, blinding light.',
    'And the violet Shard fell into the Hollow — where something patient has been waiting ever since.',
    'Now the Shards stir again. The seals are failing. A war with no honest side begins once more.',
  ];

  /// Every line in the campaign, in the order a player hears it — the opening
  /// cinematic first, then the chapters.
  static List<NarrationClip> all() {
    final clips = <NarrationClip>[];

    for (var f = 0; f < introLines.length; f++) {
      clips.add(NarrationClip(
        id: clipId(introId, f, slotBeat, 0),
        chapterId: introId,
        speaker: '',
        text: introLines[f],
      ));
    }

    for (final chapter in storyChapters) {
      for (var s = 0; s < chapter.stages.length; s++) {
        final stage = chapter.stages[s];

        void take(List<DialogueLine> lines, String slot) {
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.text.trim().isEmpty) continue;
            clips.add(NarrationClip(
              id: clipId(chapter.id, s, slot, i),
              chapterId: chapter.id,
              speaker: line.speaker,
              text: line.text,
            ));
          }
        }

        final beat = stage.beat;
        if (beat != null) take(beat.dialogue, slotBeat);

        final battle = stage.battle;
        if (battle != null) {
          take(battle.preBattle, slotPre);
          take(battle.victory, slotVictory);
        }
      }
    }
    return clips;
  }
}
