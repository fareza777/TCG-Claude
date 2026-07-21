import 'package:flutter/material.dart';

import 'main.dart';

/// Branded splash shown on launch: the emblem + wordmark animate in, then
/// the app transitions to the main menu.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..forward();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, a, _) =>
                FadeTransition(opacity: a, child: const MenuScreen()),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/ui/menu_bg.webp',
              fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.4,
                colors: [Color(0x880B0D12), Color(0xF00B0D12)],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = Curves.easeOut.transform(
                    (_ctrl.value / 0.6).clamp(0.0, 1.0));
                final glow = (0.5 +
                        0.5 *
                            (1 -
                                (2 * (_ctrl.value - 0.5)).abs()))
                    .clamp(0.0, 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: t,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFC9A86A)
                                    .withValues(alpha: 0.4 * glow),
                                blurRadius: 40 * glow)
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/ui/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFE6CE96),
                                  size: 80)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: t,
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Color(0xFFF4ECD4),
                            Color(0xFFC9A86A),
                            Color(0xFF8A713A)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(r),
                        child: const Text('SHARDFALL',
                            style: TextStyle(
                                fontFamily: 'Cinzel',
                                fontSize: 40,
                                letterSpacing: 6,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: (t - 0.3).clamp(0.0, 1.0) / 0.7,
                      child: const Text('THE SUNDERING',
                          style: TextStyle(
                              color: Color(0xFFD8CCAE),
                              fontSize: 11,
                              letterSpacing: 5)),
                    ),
                    const SizedBox(height: 40),
                    Opacity(
                      opacity: t * 0.8,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFFC9A86A))),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
