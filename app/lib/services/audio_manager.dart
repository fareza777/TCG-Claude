import 'package:audioplayers/audioplayers.dart';

/// Central audio: looping ambient music + one-shot SFX. Toggled by the
/// player's saved preferences (see SaveService).
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _music = AudioPlayer();
  final List<AudioPlayer> _sfxPool =
      List.generate(4, (_) => AudioPlayer());
  int _sfxIndex = 0;

  bool musicOn = true;
  bool sfxOn = true;
  bool _musicPlaying = false;

  Future<void> init({required bool music, required bool sfx}) async {
    musicOn = music;
    sfxOn = sfx;
    await _music.setReleaseMode(ReleaseMode.loop);
    for (final p in _sfxPool) {
      await p.setReleaseMode(ReleaseMode.stop);
    }
    if (musicOn) await startMusic();
  }

  Future<void> startMusic() async {
    if (_musicPlaying) return;
    try {
      await _music.setVolume(0.8);
      await _music.play(AssetSource('audio/ambient.wav'));
      _musicPlaying = true;
    } catch (_) {
      // audio is non-essential; never let it crash gameplay
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    if (on) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  void setSfx(bool on) => sfxOn = on;

  /// Fire a one-shot sound effect. [name] is a file stem in assets/audio.
  Future<void> sfx(String name, {double volume = 0.7}) async {
    if (!sfxOn) return;
    try {
      final player = _sfxPool[_sfxIndex];
      _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/$name.wav'));
    } catch (_) {}
  }

  // Semantic helpers used across the UI.
  void tap() => sfx('ui_tap', volume: 0.5);
  void cardPlay() => sfx('card_play');
  void attack() => sfx('attack');
  void damage() => sfx('damage', volume: 0.8);
  void reward() => sfx('reward');
  void victory() => sfx('victory', volume: 0.85);
  void defeat() => sfx('defeat', volume: 0.85);
}
