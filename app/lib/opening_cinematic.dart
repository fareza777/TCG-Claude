import 'package:flutter/material.dart';

import 'services/audio_manager.dart';
import 'story/narration.dart';

/// A single static-art frame with a Ken Burns pan/zoom and narration.
class CinematicFrame {
  final String art; // asset stem under assets/art or a full asset path
  final String text;
  final bool fullPath;
  final Alignment begin;
  final Alignment end;
  const CinematicFrame(this.art, this.text,
      {this.fullPath = false,
      this.begin = Alignment.topLeft,
      this.end = Alignment.bottomRight});
}

// The Sundering, told in static art. All lore is original (IP-safe) and
// matches docs/STORY.md.
/// Public so the voice-over pipeline reads the same lines the screen shows.
final openingFrames = <CinematicFrame>[
  CinematicFrame('assets/ui/menu_bg.webp',
      Narration.introLines[0],
      fullPath: true, begin: Alignment.center, end: Alignment.topCenter),
  CinematicFrame('SF001-211',
      Narration.introLines[1],
      begin: Alignment.bottomRight, end: Alignment.topLeft),
  CinematicFrame('SF001-101',
      Narration.introLines[2],
      begin: Alignment.topLeft, end: Alignment.bottomRight),
  CinematicFrame('SF001-221',
      Narration.introLines[3],
      begin: Alignment.topRight, end: Alignment.bottomLeft),
  CinematicFrame('SF001-043',
      Narration.introLines[4],
      begin: Alignment.bottomLeft, end: Alignment.topRight),
  CinematicFrame('SF001-063',
      Narration.introLines[5],
      begin: Alignment.center, end: Alignment.bottomRight),
  CinematicFrame('SF001-091',
      Narration.introLines[6],
      begin: Alignment.topRight, end: Alignment.center),
  CinematicFrame('SF001-227',
      Narration.introLines[7],
      begin: Alignment.bottomRight, end: Alignment.topLeft),
];

/// Full-screen opening cinematic assembled from static art. Auto-advances,
/// tap to skip a frame, "Skip" to leave. Calls [onDone] when finished.
class OpeningCinematic extends StatefulWidget {
  final VoidCallback onDone;
  const OpeningCinematic({super.key, required this.onDone});

  @override
  State<OpeningCinematic> createState() => _OpeningCinematicState();
}

class _OpeningCinematicState extends State<OpeningCinematic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _i = 0;
  bool _leaving = false;

  /// How long a frame's Ken Burns move takes. It no longer decides when the
  /// scene changes — the narration does.
  static const _frameMs = 5600;

  /// A frame stays up at least this long even if its line is short, and never
  /// longer than the ceiling if audio stalls or the clip is missing.
  static const _minFrame = Duration(milliseconds: 2600);
  static const _maxFrame = Duration(seconds: 22);

  int _playToken = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: _frameMs))
      ..forward();
    _playFrame();
  }

  @override
  void dispose() {
    AudioManager.instance.stopVoice();
    _ctrl.dispose();
    super.dispose();
  }

  /// Show a frame for as long as its narration needs, then move on.
  Future<void> _playFrame() async {
    final token = ++_playToken;
    _ctrl.forward(from: 0);

    final spoken = AudioManager.instance
        .speak(Narration.clipId(Narration.introId, _i, Narration.slotBeat, 0));

    await Future.any([
      Future.wait([spoken, Future<void>.delayed(_minFrame)]),
      Future<void>.delayed(_maxFrame),
    ]);

    // A tap (or leaving) started a different frame while we were waiting.
    if (!mounted || _leaving || token != _playToken) return;
    _advance();
  }

  void _advance() {
    if (_leaving) return;
    if (_i < openingFrames.length - 1) {
      setState(() => _i++);
      _playFrame();
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_leaving) return;
    _leaving = true;
    AudioManager.instance.stopVoice();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final frame = openingFrames[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ken Burns art (cross-fades on frame change via the ValueKey).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: _KenBurns(
                key: ValueKey(_i),
                frame: frame,
                controller: _ctrl,
              ),
            ),
            // Cinematic letterbox + legibility scrim.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0x22000000),
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0xE6000000),
                    ],
                    stops: [0, 0.14, 0.4, 0.72, 1],
                  ),
                ),
              ),
            ),
            // Narration.
            Positioned(
              left: 26,
              right: 26,
              bottom: 64,
              child: _Narration(key: ValueKey('t$_i'), text: frame.text),
            ),
            // Progress ticks.
            Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var j = 0; j < openingFrames.length; j++)
                    Container(
                      width: j == _i ? 18 : 6,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: j <= _i
                            ? const Color(0xFFC9A86A)
                            : Colors.white24,
                      ),
                    ),
                ],
              ),
            ),
            // Skip.
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip  ▸▸',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 1)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KenBurns extends StatelessWidget {
  final CinematicFrame frame;
  final AnimationController controller;
  const _KenBurns({super.key, required this.frame, required this.controller});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      frame.fullPath ? frame.art : 'assets/art/${frame.art}.webp',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF10141F)),
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        final scale = 1.06 + 0.12 * t;
        final align = Alignment.lerp(frame.begin, frame.end, t)!;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            alignment: align,
            child: child,
          ),
        );
      },
      child: img,
    );
  }
}

class _Narration extends StatefulWidget {
  final String text;
  const _Narration({super.key, required this.text});

  @override
  State<_Narration> createState() => _NarrationState();
}

class _NarrationState extends State<_Narration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            color: Color(0xFFF0E9D6),
            fontSize: 19,
            height: 1.5,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black, blurRadius: 12)],
          ),
        ),
      ),
    );
  }
}
