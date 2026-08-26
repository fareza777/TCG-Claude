import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/audio_manager.dart';
import '../theme.dart';

/// Who made this, what version you are running, and the two things a player
/// might actually want to do from here: rate it, or send it to someone.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const developer = 'F7 Developer';
  static const packageName = 'com.shardfall.shardfall';
  static const storeUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (build ${info.buildNumber})');
    } catch (_) {
      // A missing version is not worth an error to the player.
    }
  }

  /// Open the Play listing. Tries the Play app first so the rating sheet lands
  /// where a player expects, then falls back to the browser.
  Future<void> _rate() async {
    AudioManager.instance.tap();
    final market = Uri.parse('market://details?id=${AboutScreen.packageName}');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Play app missing or blocked; the web listing still works.
    }
    try {
      await launchUrl(Uri.parse(AboutScreen.storeUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      _tell('Could not open the Play Store.');
    }
  }

  Future<void> _share() async {
    AudioManager.instance.tap();
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Shardfall — a card game about five cities and the thing under '
            'them.\n${AboutScreen.storeUrl}',
        subject: 'Shardfall: The Sundering',
      ));
    } catch (_) {
      _tell('Could not open the share sheet.');
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                      tooltip: 'Back',
                    ),
                    const Text('About',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/ui/app_icon_shardfall.png',
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.auto_awesome,
                              size: 84,
                              color: Color(0xFFE6CE96)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text('SHARDFALL',
                          style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('SET I — THE SUNDERING',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              letterSpacing: 3)),
                    ),
                    const SizedBox(height: 26),
                    _row(Icons.code, 'Developer', AboutScreen.developer),
                    _row(Icons.tag, 'Version',
                        _version.isEmpty ? '—' : _version),
                    const SizedBox(height: 22),
                    _action(
                      icon: Icons.star_rate_rounded,
                      label: 'Rate on Google Play',
                      hint: 'Reviews are how anyone finds this.',
                      onTap: _rate,
                    ),
                    const SizedBox(height: 10),
                    _action(
                      icon: Icons.ios_share,
                      label: 'Share Shardfall',
                      hint: 'Send it to someone who likes card games.',
                      onTap: _share,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'All art, cards, and story in Shardfall are original '
                      'work. Any resemblance to another card game is the '
                      'genre, not the game.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFC9A86A)),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: const Color(0xFFC9A86A).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFC9A86A), size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(hint,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
