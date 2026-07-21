import 'package:flutter/material.dart';

/// A single static-art frame with a Ken Burns pan/zoom and narration.
class _Frame {
  final String art; // asset stem under assets/art or a full asset path
  final String text;
  final bool fullPath;
  final Alignment begin;
  final Alignment end;
  const _Frame(this.art, this.text,
      {this.fullPath = false,
      this.begin = Alignment.topLeft,
      this.end = Alignment.bottomRight});
}

// The Sundering, told in static art. All lore is original (IP-safe) and
// matches docs/STORY.md.
const _frames = <_Frame>[
  _Frame('assets/ui/menu_bg.webp',
      'A thousand years ago, the star Vael hung whole in the night — and the world of Aethyr slept beneath its light.',
      fullPath: true, begin: Alignment.center, end: Alignment.topCenter),
  _Frame('SF001-211',
      'Then it shattered. Five burning Shards fell upon the world, and where each one struck, a Dominion woke.',
      begin: Alignment.bottomRight, end: Alignment.topLeft),
  _Frame('SF001-101',
      'Where the emerald Shard fell, the forests of Sylvaris remembered how to move — and chose their wardens.',
      begin: Alignment.topLeft, end: Alignment.bottomRight),
  _Frame('SF001-221',
      'Where the crimson Shard fell, the forges of Ashmar burned a thousand years without fuel.',
      begin: Alignment.topRight, end: Alignment.bottomLeft),
  _Frame('SF001-043',
      'The cyan Shard sank beneath Meridine, into an archive of truths the tide would rather keep drowned.',
      begin: Alignment.bottomLeft, end: Alignment.topRight),
  _Frame('SF001-063',
      'The golden Shard crowned the Concord of Dawn in borrowed, blinding light.',
      begin: Alignment.center, end: Alignment.bottomRight),
  _Frame('SF001-091',
      'And the violet Shard fell into the Hollow — where something patient has been waiting ever since.',
      begin: Alignment.topRight, end: Alignment.center),
  _Frame('SF001-227',
      'Now the Shards stir again. The seals are failing. A war with no honest side begins once more.',
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

  static const _frameMs = 5600;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: _frameMs))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (_leaving) return;
    if (_i < _frames.length - 1) {
      setState(() => _i++);
      _ctrl.forward(from: 0);
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_leaving) return;
    _leaving = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frames[_i];
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
                  for (var j = 0; j < _frames.length; j++)
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
  final _Frame frame;
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
