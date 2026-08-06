// Composes the two looping music beds as 16-bit mono WAVs:
//
//   ambient.wav         menu/story/collection — calm dark-fantasy theme
//   battle_ambient.wav  duels — same family, lower and with a soft pulse
//
// Revision 2: the first revision still layered a filtered-noise "wind" bed
// and a sub-octave bass under the pads. On phone speakers the noise read as
// a constant rumble and the sub as distortion, so both are gone. What remains
// is purely musical: a soft string pad moving through Dm – Bb – Gm – A (the
// i–VI–iv–V loop dark fantasy runs on), a gentle harp arpeggio carrying the
// harmony, and a sparse bell melody on top.
//
// Seamlessness is by construction: chord pads are mixed through equal-power
// raised-cosine windows that partition unity across the whole loop including
// the seam, every LFO completes an integer number of cycles per loop, and no
// pluck, bell, or pulse envelope is allowed to cross the boundary.
//
// Run: dart run tools/audio/generate_music.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sr = 22050;
const chordSeconds = 14.0;
const chords = 4;
const loopSeconds = chordSeconds * chords; // 56s
const xfadeSeconds = 4.0;

double midi(int n) => 440.0 * pow(2.0, (n - 69) / 12.0);

/// One chord voicing. Nothing below ~110 Hz: phone speakers turn a true
/// sub-octave into rumble, so the root itself is the floor.
class Chord {
  final int root, fifth, third, octave, ninth;
  const Chord(this.root, this.fifth, this.third, this.octave, this.ninth);
}

// Dm – Bb – Gm – A. The V resolves into the i across the loop seam, so the
// ending literally becomes the beginning.
const progression = [
  Chord(50, 57, 53, 62, 64), // Dm: D3 A3 F3 D4 E4
  Chord(46, 53, 62, 58, 60), // Bb: Bb2 F3 D4 Bb3 C4
  Chord(43, 50, 58, 55, 57), // Gm: G2 D3 Bb3 G3 A3
  Chord(45, 52, 61, 57, 59), // A:  A2 E3 C#4 A3 B3
];

/// Bell melody: (chord index, seconds into the chord, midi note, gain).
/// Pentatonic-safe against each chord, kept clear of the loop seam so no
/// decay ever crosses it.
const bells = [
  (0, 2.0, 74, 0.15), // D5 over Dm
  (0, 5.6, 69, 0.11), // A4
  (0, 9.2, 77, 0.12), // F5
  (1, 1.6, 70, 0.13), // Bb4 over Bb
  (1, 5.2, 74, 0.11), // D5
  (1, 8.8, 65, 0.10), // F4
  (2, 2.4, 79, 0.13), // G5 over Gm
  (2, 6.0, 74, 0.11), // D5
  (2, 9.6, 70, 0.10), // Bb4
  (3, 2.0, 69, 0.12), // A4 over A
  (3, 5.6, 73, 0.11), // C#5 — the leading pull back to D
  (3, 8.4, 76, 0.09), // E5
];

/// Equal-power window for chord [i]: 1 across its segment, crossfading with
/// its neighbours over [xfadeSeconds] at each edge. Windows for all chords
/// sum to 1 everywhere (wrap-around included), which is what makes the loop
/// seamless.
double chordWindow(int i, double t) {
  final seg = loopSeconds / chords;
  // Distance from the centre of chord i's segment, on the circle.
  final centre = (i + 0.5) * seg;
  var d = (t - centre) % loopSeconds;
  if (d > loopSeconds / 2) d -= loopSeconds;
  if (d < -loopSeconds / 2) d += loopSeconds;
  final ad = d.abs();
  final halfFlat = seg / 2 - xfadeSeconds / 2;
  if (ad <= halfFlat) return 1.0;
  if (ad >= halfFlat + xfadeSeconds) return 0.0;
  final x = (ad - halfFlat) / xfadeSeconds; // 0..1 through the crossfade
  return cos(x * pi / 2);
}

double padVoice(double freq, double amp, double tremCycles, double tremDepth,
    double t, double loopLen) {
  final lfo = (1.0 - tremDepth) +
      tremDepth * (0.5 + 0.5 * sin(2 * pi * tremCycles * t / loopLen));
  return amp * lfo * sin(2 * pi * freq * t);
}

double padAt(double t, {required bool battle}) {
  var s = 0.0;
  for (var i = 0; i < chords; i++) {
    final w = chordWindow(i, t);
    if (w == 0.0) continue;
    final c = progression[i];
    var chord = 0.0;
    chord += padVoice(midi(c.root), 0.80, 2, 0.25, t, loopSeconds);
    chord += padVoice(midi(c.fifth), 0.50, 3, 0.30, t, loopSeconds);
    chord += padVoice(midi(c.third), 0.30, 2, 0.35, t, loopSeconds);
    chord += padVoice(midi(c.octave), 0.36, 4, 0.40, t, loopSeconds);
    if (!battle) {
      chord += padVoice(midi(c.ninth), 0.14, 5, 0.55, t, loopSeconds);
    }
    s += w * chord;
  }
  return s;
}

/// A soft struck tone: fast attack, exponential decay, fundamental plus two
/// gentle partials. Used for both the bells and the harp arpeggio.
void addPluck(
    List<double> buf, double start, int note, double gain, double decay) {
  final f = midi(note);
  final n = (sr * decay * 4).round(); // envelope is inaudible by 4x decay
  final at = (start * sr).round();
  for (var i = 0; i < n; i++) {
    final idx = at + i;
    if (idx >= buf.length) return; // never cross the seam
    final t = i / sr;
    final env = exp(-t / decay);
    final attack = min(1.0, t / 0.006);
    buf[idx] += gain *
        attack *
        env *
        (sin(2 * pi * f * t) +
            0.30 * sin(2 * pi * f * 2.003 * t) +
            0.10 * sin(2 * pi * f * 2.99 * t));
  }
}

/// The harp figure: an unhurried root – fifth – octave – ninth – octave –
/// fifth climb, one note every 1.75s so each chord gets exactly eight.
void addArpeggio(List<double> buf, {required bool battle}) {
  const step = 1.75;
  for (var c = 0; c < chords; c++) {
    final chord = progression[c];
    final pattern = battle
        ? [chord.root, chord.fifth, chord.octave, chord.fifth]
        : [
            chord.root,
            chord.fifth,
            chord.octave,
            chord.ninth,
            chord.octave,
            chord.fifth,
          ];
    final base = c * chordSeconds + 0.4;
    for (var n = 0; n < 8; n++) {
      final note = pattern[n % pattern.length] + 12; // harp register
      final gain = (battle ? 0.085 : 0.10) * (n % 2 == 0 ? 1.0 : 0.8);
      addPluck(buf, base + n * step, note, gain, 0.55);
    }
  }
}

void writeWav(String path, List<double> samples) {
  final sw = Stopwatch()..start();
  var maxAbs = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > maxAbs) maxAbs = a;
  }
  final gain = 0.6 / maxAbs;
  final n = samples.length;
  final bytes = ByteData(44 + n * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sr, Endian.little);
  bytes.setUint32(28, sr * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = (samples[i] * gain * 32000).clamp(-32768, 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln(
      'wrote $path (${(n / sr).toStringAsFixed(1)}s, ${(n * 2 / 1024).round()} KB) in ${sw.elapsedMilliseconds}ms');
}

List<double> compose({required bool battle}) {
  final count = (sr * loopSeconds).round();
  final buf = List<double>.filled(count, 0.0);

  for (var i = 0; i < count; i++) {
    buf[i] += padAt(i / sr, battle: battle);
  }

  addArpeggio(buf, battle: battle);

  if (battle) {
    // Soft low pulse on the chord root, 2 beats per second — 112 across the
    // loop, so the pattern lands exactly on the seam.
    for (var i = 0; i < count; i++) {
      final t = i / sr;
      final phase = (t * 2.0) % 1.0;
      var root = 0.0;
      for (var c = 0; c < chords; c++) {
        root += chordWindow(c, t) * midi(progression[c].root - 12);
      }
      buf[i] += 0.22 * exp(-9.0 * phase) * sin(2 * pi * root * t);
    }
  } else {
    for (final (chord, at, note, gain) in bells) {
      addPluck(buf, chord * chordSeconds + at, note, gain, 0.7);
    }
  }
  return buf;
}

void main() {
  final out = Directory('app/assets/audio');
  writeWav('${out.path}/ambient.wav', compose(battle: false));
  writeWav('${out.path}/battle_ambient.wav', compose(battle: true));
}
