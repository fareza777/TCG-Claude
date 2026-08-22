import 'dart:async';

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

  /// Narration gets its own player: a spoken line must interrupt the previous
  /// line cleanly when the player taps ahead, which a shared SFX pool cannot do.
  final AudioPlayer _voice = AudioPlayer();
  bool _speaking = false;
  Completer<void>? _voiceDone;

  bool musicOn = true;
  bool sfxOn = true;
  bool voiceOn = true;
  bool _musicPlaying = false;
  bool _musicPaused = false;

  /// The ambient track for the current section — 'ambient' (menu/story/collection)
  /// or 'battle_ambient' (duels). Falls back to 'ambient' if a file is missing.
  String _currentTrack = 'ambient';

  Future<void> init({
    required bool music,
    required bool sfx,
    bool voice = true,
  }) async {
    musicOn = music;
    sfxOn = sfx;
    voiceOn = voice;
    await _music.setReleaseMode(ReleaseMode.loop);
    for (final p in _sfxPool) {
      await p.setReleaseMode(ReleaseMode.stop);
    }
    await _voice.setReleaseMode(ReleaseMode.stop);
    _voice.onPlayerComplete.listen((_) => _endSpeech());
    if (musicOn) await startMusic();
  }

  /// Switch the ambient bed for a section. Menus/story use the calm pad; the
  /// battle screen uses a more driving bed. No-op if already on that track.
  Future<void> playTrack(String track) async {
    _currentTrack = track;
    _musicPaused = false;
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
    if (_musicPaused) {
      // Backgrounded earlier: pick the bed back up where it left off.
      _musicPaused = false;
      try {
        await _music.resume();
        _musicPlaying = true;
        return;
      } catch (_) {}
    }
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
    _musicPaused = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  /// Pauses the bed where it is, for when the app goes to the background.
  /// Playing on while the player is in another app reads as a bug, and
  /// [ensurePlaying] picks the track back up right where it left off.
  Future<void> pauseMusic() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    _musicPaused = true;
    try {
      await _music.pause();
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

  Future<void> setVoice(bool on) async {
    voiceOn = on;
    if (!on) await stopVoice();
  }

  /// Speak one narration clip, replacing whatever was being said.
  ///
  /// Returns a future that completes when the line has finished — callers that
  /// pace themselves by the voice (the opening cinematic) await it, so a scene
  /// can never cut its own narration off mid-sentence. Callers the player
  /// paces themselves (story beats) simply ignore it.
  ///
  /// A missing file is not an error the player should ever see: the campaign
  /// stays fully playable in silence, so an ungenerated line just reads, and
  /// the future completes immediately so nothing waits on silence.
  Future<void> speak(String clipId) async {
    if (!voiceOn) return;
    _resolveVoiceDone();
    final done = Completer<void>();
    _voiceDone = done;
    try {
      await _voice.stop();
      await _duckMusic(true);
      _speaking = true;
      await _voice.play(AssetSource('vo/$clipId.mp3'));
    } catch (_) {
      await _endSpeech();
      return;
    }
    return done.future;
  }

  void _resolveVoiceDone() {
    final pending = _voiceDone;
    _voiceDone = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> stopVoice() async {
    try {
      await _voice.stop();
    } catch (_) {}
    await _endSpeech();
  }

  Future<void> _endSpeech() async {
    _resolveVoiceDone();
    if (!_speaking) return;
    _speaking = false;
    await _duckMusic(false);
  }

  /// Pull the ambient bed down while someone is talking, so the line stays
  /// intelligible on a phone speaker.
  Future<void> _duckMusic(bool down) async {
    if (!musicOn) return;
    try {
      await _music.setVolume(down ? 0.25 : 1.0);
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
