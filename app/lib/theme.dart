import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// Visual identity per Dominion — single source of truth for the app.
class DominionStyle {
  final List<Color> frame; // dark → darker vertical gradient
  final Color orb; // aether/mana orb fill
  final Color orbText;
  final Color glow; // accent glow for fx
  final IconData icon;

  const DominionStyle({
    required this.frame,
    required this.orb,
    required this.orbText,
    required this.glow,
    required this.icon,
  });

  static const _styles = <Dominion, DominionStyle>{
    Dominion.verdance: DominionStyle(
      frame: [Color(0xFF3F7D3A), Color(0xFF2B5A2A), Color(0xFF1C3D1C)],
      orb: Color(0xFFA8D18A),
      orbText: Color(0xFF1C3312),
      glow: Color(0xFF7FE0A8),
      icon: Icons.eco,
    ),
    Dominion.pyre: DominionStyle(
      frame: [Color(0xFFB8452A), Color(0xFF8A2F1C), Color(0xFF5A1C10)],
      orb: Color(0xFFE07A4A),
      orbText: Color(0xFF3A1608),
      glow: Color(0xFFFFB347),
      icon: Icons.local_fire_department,
    ),
    Dominion.tide: DominionStyle(
      frame: [Color(0xFF3A72B8), Color(0xFF255089), Color(0xFF16304F)],
      orb: Color(0xFF6FB0DC),
      orbText: Color(0xFF0D2740),
      glow: Color(0xFF7FE0F0),
      icon: Icons.water_drop,
    ),
    Dominion.dawn: DominionStyle(
      frame: [Color(0xFFB89A5A), Color(0xFF8A713A), Color(0xFF5C4A24)],
      orb: Color(0xFFE8D49A),
      orbText: Color(0xFF4A3A10),
      glow: Color(0xFFFFE9B0),
      icon: Icons.wb_sunny,
    ),
    Dominion.gloom: DominionStyle(
      frame: [Color(0xFF6A4A8A), Color(0xFF4A2F66), Color(0xFF2C1A42)],
      orb: Color(0xFFB48AD1),
      orbText: Color(0xFF2A1140),
      glow: Color(0xFFD9AFFF),
      icon: Icons.dark_mode,
    ),
    Dominion.neutral: DominionStyle(
      frame: [Color(0xFF6E6E70), Color(0xFF4C4C50), Color(0xFF2E2E32)],
      orb: Color(0xFFBFC2C8),
      orbText: Color(0xFF2A2A33),
      glow: Color(0xFFE6E8EE),
      icon: Icons.hexagon_outlined,
    ),
  };

  static DominionStyle of(Dominion d) => _styles[d]!;

  static DominionStyle ofCard(CardDef def) =>
      of(def.dominions.isEmpty ? Dominion.neutral : def.dominions.first);
}

/// Parchment tones shared by every card face.
class Parchment {
  static const titleTop = Color(0xFFDCD3B8);
  static const titleBottom = Color(0xFFC2B590);
  static const boxTop = Color(0xFFE9E2CF);
  static const boxBottom = Color(0xFFD4C9AC);
  static const border = Color(0xFF8A7C52);
  static const ink = Color(0xFF241D10);
  static const inkSoft = Color(0xFF4A3F28);
}

/// Global UI preferences read by animation-heavy widgets.
class MotionPrefs {
  static bool reduce = false;
}

class AppTheme {
  static const bgTop = Color(0xFF171A21);
  static const bgBottom = Color(0xFF0B0D12);
  static const panel = Color(0xFF1F2430);
  static const panelBorder = Color(0xFF39415A);
  static const textPrimary = Color(0xFFE8E4D8);
  static const textMuted = Color(0xFF9A97A8);
  static const danger = Color(0xFFE0574A);
  static const health = Color(0xFFE05E6E);

  static ThemeData build() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgBottom,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9A86A),
          surface: panel,
        ),
        fontFamily: 'serif',
        fontFamilyFallback: const ['Georgia', 'Times New Roman'],
      );
}

/// Rarity gem colors.
Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFFB08D57),
      Rarity.uncommon => const Color(0xFFB8C0CC),
      Rarity.rare => const Color(0xFFE3B341),
      Rarity.epic => const Color(0xFFB06AE0),
      Rarity.legendary => const Color(0xFFFF8A5C),
    };
