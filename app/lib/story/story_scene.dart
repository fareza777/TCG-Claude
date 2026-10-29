import 'package:flutter/material.dart';
import '../theme.dart';

/// Slow illustrated camera movement and a true previous-scene crossfade.
/// Reduced motion removes both movement and fades. Controllers stop when the
/// scene leaves the tree; dialogue owns its own independent voice lifetime.
class StoryScene extends StatefulWidget {
  final String artAsset;
  final String? previousArtAsset;
  const StoryScene({super.key, required this.artAsset, this.previousArtAsset});

  @override
  State<StoryScene> createState() => _StorySceneState();
}

class _StorySceneState extends State<StoryScene> with TickerProviderStateMixin {
  late final _camera = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _reduced = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(covariant StoryScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artAsset != widget.artAsset) _reveal.value = 0;
    _configure();
  }

  void _configure() {
    _reduced = MotionPrefs.reduce || MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _camera.stop();
      _camera.value = 0;
      _reveal.value = 1;
    } else {
      if (!_camera.isAnimating) _camera.repeat(reverse: true);
      if (!_reveal.isCompleted) _reveal.forward();
    }
  }

  Widget _image(String asset) => Image.asset(
    'assets/art/$asset.webp',
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) => Container(color: AppTheme.panel),
  );

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (!_reduced && widget.previousArtAsset != null)
          _image(widget.previousArtAsset!),
        AnimatedBuilder(
          animation: Listenable.merge([_camera, _reveal]),
          child: _image(widget.artAsset),
          builder: (context, child) => Opacity(
            opacity: _reduced ? 1 : Curves.easeOut.transform(_reveal.value),
            child: FractionalTranslation(
              translation: _reduced
                  ? Offset.zero
                  : Offset(
                      -0.018 + _camera.value * 0.036,
                      0.012 - _camera.value * 0.024,
                    ),
              child: Transform.scale(
                key: const ValueKey('story-scene-camera'),
                scale: _reduced ? 1 : 1.07 + _camera.value * 0.055,
                child: child,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _camera.dispose();
    _reveal.dispose();
    super.dispose();
  }
}

/// Text-only transitions never retain an outgoing audio owner.
class StoryDialogueTransition extends StatelessWidget {
  final Object identity;
  final Widget child;
  const StoryDialogueTransition({
    super.key,
    required this.identity,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MotionPrefs.reduce || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(identity), child: child),
  );
}
