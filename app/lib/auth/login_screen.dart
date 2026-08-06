import 'package:flutter/material.dart';

import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/save_service.dart';
import '../theme.dart';

/// The one-time choice between a linked account and guest play.
///
/// This screen exists because the alternative was worse: the game used to
/// fire a Google account prompt out of a silent startup re-auth, which could
/// surface in the middle of the opening cinematic. Now nothing Google-shaped
/// appears until the player stands here and presses the button themselves.
///
/// Pops with `true` once a Google account is linked, `false` when the player
/// picks guest mode. Guests keep the whole single-player game; PvP and Gold
/// purchases stay account-only, and both say so where they are offered.
class LoginScreen extends StatefulWidget {
  final AuthService auth;
  final SaveService save;

  const LoginScreen({super.key, required this.auth, required this.save});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final ok = await widget.auth.signIn();
    if (!mounted) return;
    if (ok) {
      await widget.save.setAccountLinked(true);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
  }

  Future<void> _guest() async {
    AudioManager.instance.tap();
    await widget.save.setGuestMode(true);
    if (mounted) Navigator.of(context).pop(false);
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30B0D12),
                  Color(0x730B0D12),
                  Color(0xF20B0D12),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC9A86A)
                                .withValues(alpha: 0.35),
                            blurRadius: 34,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/ui/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFE6CE96),
                                size: 56)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [
                          Color(0xFFF4ECD4),
                          Color(0xFFC9A86A),
                          Color(0xFF8A713A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(r),
                      child: const Text('SHARDFALL',
                          style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 32,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 4),
                    const Text('THE SUNDERING',
                        style: TextStyle(
                            color: Color(0xFFD8CCAE),
                            fontSize: 10,
                            letterSpacing: 4)),
                    const SizedBox(height: 34),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        decoration: BoxDecoration(
                          color: AppTheme.panel.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFC9A86A)
                                  .withValues(alpha: 0.45)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('CHOOSE HOW YOU PLAY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    letterSpacing: 2.5,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : _signIn,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    Color(0xFF1C1508))))
                                    : const Text('G',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900)),
                                label: Text(_busy
                                    ? 'Signing in...'
                                    : 'SIGN IN WITH GOOGLE'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC9A86A),
                                  foregroundColor: const Color(0xFF1C1508),
                                  disabledBackgroundColor:
                                      const Color(0xFFC9A86A)
                                          .withValues(alpha: 0.6),
                                  disabledForegroundColor:
                                      const Color(0xFF1C1508),
                                  textStyle: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _guest,
                                icon: const Icon(Icons.person_outline,
                                    size: 18),
                                label: const Text('PLAY AS GUEST'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textMuted,
                                  side: BorderSide(
                                      color: AppTheme.panelBorder
                                          .withValues(alpha: 0.9)),
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Guest progress lives only on this device. '
                              'PvP and Gold purchases need a Google account '
                              '— you can link one later in Settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  height: 1.45),
                            ),
                            ListenableBuilder(
                              listenable: widget.auth,
                              builder: (context, _) {
                                final failure = widget.auth.message;
                                if (failure == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(failure,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppTheme.danger,
                                          fontSize: 11)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
