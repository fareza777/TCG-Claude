# Synthesize royalty-free SFX + ambient loop as 16-bit mono WAV.
$out = "C:\TCG Claude\app\assets\audio"
New-Item -ItemType Directory -Force $out | Out-Null
$sr = 22050

function Write-Wav([double[]]$samples, [string]$path) {
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  $n = $samples.Length
  $bytes = $n * 2
  $bw.Write([char[]]'RIFF'); $bw.Write([int](36 + $bytes))
  $bw.Write([char[]]'WAVE'); $bw.Write([char[]]'fmt ')
  $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
  $bw.Write([int]$sr); $bw.Write([int]($sr * 2))
  $bw.Write([int16]2); $bw.Write([int16]16)
  $bw.Write([char[]]'data'); $bw.Write([int]$bytes)
  foreach ($s in $samples) {
    $v = [int]([math]::Max(-1.0, [math]::Min(1.0, $s)) * 32000)
    $bw.Write([int16]$v)
  }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

function Tone([double]$freq, [double]$dur, [double]$amp, [double]$decay) {
  $count = [int]($sr * $dur)
  $arr = New-Object double[] $count
  for ($i = 0; $i -lt $count; $i++) {
    $t = $i / $sr
    $env = [math]::Exp(-$decay * $t)
    $arr[$i] = $amp * $env * [math]::Sin(2 * [math]::PI * $freq * $t)
  }
  return $arr
}

function Mix([double[]]$a, [double[]]$b, [int]$offset) {
  $len = [math]::Max($a.Length, $offset + $b.Length)
  $arr = New-Object double[] $len
  for ($i = 0; $i -lt $a.Length; $i++) { $arr[$i] = $a[$i] }
  for ($i = 0; $i -lt $b.Length; $i++) { $arr[$offset + $i] += $b[$i] }
  return $arr
}

# ui_tap: soft high blip
Write-Wav (Tone 880 0.05 0.35 40) "$out\ui_tap.wav"

# card_play: upward pitch sweep
$cp = New-Object double[] ([int]($sr * 0.22))
for ($i = 0; $i -lt $cp.Length; $i++) {
  $t = $i / $sr; $f = 380 + 700 * ($t / 0.22)
  $env = [math]::Sin([math]::PI * $t / 0.22)
  $cp[$i] = 0.4 * $env * [math]::Sin(2 * [math]::PI * $f * $t)
}
Write-Wav $cp "$out\card_play.wav"

# attack: downward swipe with grit
$at = New-Object double[] ([int]($sr * 0.2))
for ($i = 0; $i -lt $at.Length; $i++) {
  $t = $i / $sr; $f = 760 - 480 * ($t / 0.2)
  $env = [math]::Exp(-6 * $t)
  $at[$i] = 0.45 * $env * [math]::Sin(2 * [math]::PI * $f * $t)
}
Write-Wav $at "$out\attack.wav"

# damage: low thud + noise
$dm = New-Object double[] ([int]($sr * 0.25))
$rng = New-Object System.Random 7
for ($i = 0; $i -lt $dm.Length; $i++) {
  $t = $i / $sr; $env = [math]::Exp(-14 * $t)
  $noise = ($rng.NextDouble() * 2 - 1) * [math]::Exp(-40 * $t) * 0.3
  $dm[$i] = 0.6 * $env * [math]::Sin(2 * [math]::PI * 110 * $t) + $noise
}
Write-Wav $dm "$out\damage.wav"

# reward: two rising coin blips
$r1 = Tone 1200 0.08 0.3 25
$r2 = Tone 1600 0.1 0.3 22
Write-Wav (Mix $r1 $r2 ([int]($sr * 0.07))) "$out\reward.wav"

# victory: C-E-G-C major arpeggio (523,659,784,1047)
$v = Tone 523 0.5 0.25 4
$v = Mix $v (Tone 659 0.5 0.25 4) ([int]($sr * 0.12))
$v = Mix $v (Tone 784 0.55 0.25 4) ([int]($sr * 0.24))
$v = Mix $v (Tone 1047 0.7 0.3 3) ([int]($sr * 0.36))
Write-Wav $v "$out\victory.wav"

# defeat: A-F-D minor descent (440,349,294)
$d = Tone 440 0.4 0.25 5
$d = Mix $d (Tone 349 0.45 0.25 5) ([int]($sr * 0.18))
$d = Mix $d (Tone 294 0.8 0.28 3) ([int]($sr * 0.36))
Write-Wav $d "$out\defeat.wav"

# ambient: a rich, evolving A-minor pad, 16s seamless loop. Each voice has
# its OWN slow tremolo at an integer number of cycles across the clip, so the
# timbre drifts and breathes (feels alive) while start==end (no click). Every
# frequency is an exact multiple of 1/16 Hz so all voices loop seamlessly.
# Overall level is pushed high (RMS-normalised toward ~0.5 peak) so it is
# clearly audible on phone speakers.
$dur = 16.0
$count = [int]($sr * $dur)
$amb = New-Object double[] $count

# (freq, baseAmp, lfoCyclesPerLoop, lfoDepth) — A minor add9 + sub + shimmer.
$voices = @(
  @(55.0,   0.55, 1, 0.35),  # sub-octave body
  @(110.0,  1.00, 1, 0.40),  # root A2
  @(165.0,  0.80, 2, 0.45),  # E3 (fifth)
  @(220.0,  0.85, 1, 0.40),  # A3 octave
  @(275.0,  0.45, 3, 0.55),  # C#? tension shimmer (5/4 * 220)
  @(330.0,  0.60, 2, 0.50),  # E4
  @(440.0,  0.35, 3, 0.60),  # A4 airy shimmer
  @(660.0,  0.18, 4, 0.70)   # E5 sparkle
)
$maxAbs = 0.0
for ($i = 0; $i -lt $count; $i++) {
  $t = $i / $sr
  $s = 0.0
  foreach ($v in $voices) {
    $f = $v[0]; $amp = $v[1]; $cyc = $v[2]; $depth = $v[3]
    # per-voice tremolo in [1-depth, 1], seamless (integer cycles across loop)
    $lfo = (1.0 - $depth) + $depth * (0.5 + 0.5 * [math]::Sin(2 * [math]::PI * ($cyc / $dur) * $t))
    $s += $amp * $lfo * [math]::Sin(2 * [math]::PI * $f * $t)
  }
  $amb[$i] = $s
  $a = [math]::Abs($s)
  if ($a -gt $maxAbs) { $maxAbs = $a }
}
# Normalise to a strong, consistent level (peak ~0.62 full scale).
$gain = 0.62 / $maxAbs
for ($i = 0; $i -lt $count; $i++) { $amb[$i] = $amb[$i] * $gain }
Write-Wav $amb "$out\ambient.wav"

# battle_ambient: a darker, more driving 16s bed for duels — same seamless-loop
# construction (integer cycles) but a lower, tenser chord + a rhythmic pulse
# (a gated low tone at 2 beats/sec) for tension without being distracting.
$bat = New-Object double[] $count
$bvoices = @(
  @(55.0,   0.90, 1, 0.30),  # sub drone
  @(82.5,   0.70, 2, 0.40),  # low E (tension)
  @(110.0,  0.85, 1, 0.35),  # root A2
  @(165.0,  0.55, 3, 0.50),  # E3
  @(220.0,  0.45, 2, 0.55),  # A3
  @(330.0,  0.30, 4, 0.65)   # E4 shimmer
)
$maxB = 0.0
for ($i = 0; $i -lt $count; $i++) {
  $t = $i / $sr
  $s = 0.0
  foreach ($v in $bvoices) {
    $f = $v[0]; $amp = $v[1]; $cyc = $v[2]; $depth = $v[3]
    $lfo = (1.0 - $depth) + $depth * (0.5 + 0.5 * [math]::Sin(2 * [math]::PI * ($cyc / $dur) * $t))
    $s += $amp * $lfo * [math]::Sin(2 * [math]::PI * $f * $t)
  }
  # Pulse: 32 beats across 16s (2/sec), a soft gated low thump for drive.
  $ph = ($t * 2.0) - [math]::Floor($t * 2.0)   # 0..1 each beat
  $pulseEnv = [math]::Exp(-8.0 * $ph)
  $s += 0.5 * $pulseEnv * [math]::Sin(2 * [math]::PI * 60.0 * $t)
  $bat[$i] = $s
  $a = [math]::Abs($s)
  if ($a -gt $maxB) { $maxB = $a }
}
$gainB = 0.62 / $maxB
for ($i = 0; $i -lt $count; $i++) { $bat[$i] = $bat[$i] * $gainB }
Write-Wav $bat "$out\battle_ambient.wav"

Get-ChildItem $out | Select-Object Name, @{n='KB';e={[math]::Round($_.Length/1KB)}}
