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

  /// The ambient track for the current section — 'ambient' (menu/story/collection)
  /// or 'battle_ambient' (duels). Falls back to 'ambient' if a file is missing.
  String _currentTrack = 'ambient';

  Future<void> init({required bool music, required bool sfx}) async {
    musicOn = music;
    sfxOn = sfx;
    await _music.setReleaseMode(ReleaseMode.loop);
    for (final p in _sfxPool) {
      await p.setReleaseMode(ReleaseMode.stop);
    }
    if (musicOn) await startMusic();
  }

  /// Switch the ambient bed for a section. Menus/story use the calm pad; the
  /// battle screen uses a more driving bed. No-op if already on that track.
  Future<void> playTrack(String track) async {
    _currentTrack = track;
    if (!musicOn) return;
    try {
      await _music.setVolume(1.0);
      await _music.play(AssetSource('audio/$track.wav'));
      _musicPlaying = true;
    } catch (_) {
      // Missing track? Fall back to the base ambient.
      try {
        await _music.play(AssetSource('audio/ambient.wav'));
        _musicPlaying = true;
      } catch (_) {}
    }
  }

  Future<void> startMusic() async {
    if (_musicPlaying) return;
    await playTrack(_currentTrack);
  }

  /// Re-assert playback — call when entering any screen. Handles the case where
  /// the OS paused the player (audio-focus loss) but our flag says "playing".
  Future<void> ensurePlaying() async {
    if (!musicOn) return;
    if (!_musicPlaying) {
      await playTrack(_currentTrack);
    } else {
      try {
        await _music.resume();
      } catch (_) {}
    }
  }

  /// Enter a section and make sure the right bed is playing.
  Future<void> enterSection(String track) async {
    if (track != _currentTrack) {
      await playTrack(track);
    } else {
      await ensurePlaying();
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
