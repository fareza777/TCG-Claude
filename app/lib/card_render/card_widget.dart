import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../theme.dart';

/// Premium card face. Layered frame: black bevel → gold trim → dominion
/// gradient → parchment panels. Aether costs render as iconic dominion
/// symbols (never letters). Stats render as sword/shield gem badges.
class CardWidget extends StatelessWidget {
  final CardDef def;
  final double width;
  final bool faceDown;
  final bool exerted;
  final int plusCounters;
  final int damage;

  const CardWidget({
    super.key,
    required this.def,
    this.width = 180,
    this.faceDown = false,
    this.exerted = false,
    this.plusCounters = 0,
    this.damage = 0,
  });

  double get height => width * 88 / 63;

  /// Accessibility: when on, show a rarity letter (C/U/R/E/L) next to the gem
  /// so tiers are readable without relying on colour. Set from settings.
  static bool colorblindLabels = false;

  static const _gold = Color(0xFFB9995C);
  static const _goldLight = Color(0xFFE6CE96);
  static const _goldDark = Color(0xFF6E5527);

  @override
  Widget build(BuildContext context) {
    final card = faceDown ? _back() : _face();
    // Material ancestor prevents the yellow double-underline fallback text
    // style when the card is shown in raw overlays/dialogs.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedRotation(
        turns: exerted ? 0.25 * 0.35 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: card,
      ),
    );
  }

  static const _nameFont = TextStyle(
    fontFamily: 'Cinzel',
    fontVariations: [FontVariation('wght', 700)],
  );
  static const _bodyFont = TextStyle(fontFamily: 'EBGaramond');

  // ── card back ──────────────────────────────────────────────────────────
  Widget _back() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.07),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232A44), Color(0xFF10141F)],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.55), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.5,
          height: width * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _gold.withValues(alpha: 0.25),
              Colors.transparent,
            ]),
            border: Border.all(color: _gold.withValues(alpha: 0.7), width: 1.6),
          ),
          child: Icon(Icons.auto_awesome, color: _goldLight, size: width * 0.2),
        ),
      ),
    );
  }

  // ── card face ──────────────────────────────────────────────────────────
  Widget _face() {
    final style = DominionStyle.ofCard(def);
    final r = width / 180.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF07070A),
        borderRadius: BorderRadius.circular(13 * r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 8 * r,
              offset: Offset(0, 3 * r)),
        ],
      ),
      padding: EdgeInsets.all(3.5 * r),
      // gold trim ring
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_goldLight, _gold, _goldDark, _gold, _goldLight],
          ),
          borderRadius: BorderRadius.circular(10 * r),
        ),
        padding: EdgeInsets.all(1.6 * r),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: style.frame,
            ),
            borderRadius: BorderRadius.circular(8.5 * r),
          ),
          padding: EdgeInsets.all(5 * r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleBar(style, r),
              SizedBox(height: 4 * r),
              Expanded(flex: 58, child: _artBox(style, r)),
              SizedBox(height: 4 * r),
              _typeLine(style, r),
              SizedBox(height: 4 * r),
              Expanded(flex: 42, child: _textBox(style, r)),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panel(Color top, Color bottom, double radius) =>
      BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom]),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _goldDark.withValues(alpha: 0.9), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      );

  Widget _titleBar(DominionStyle style, double r) {
    return Container(
      height: 25 * r,
      decoration: _panel(Parchment.titleTop, Parchment.titleBottom, 5 * r),
      padding: EdgeInsets.only(left: 7 * r, right: 4 * r),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                def.name,
                maxLines: 1,
                softWrap: false,
                style: _nameFont.copyWith(
                  color: Parchment.ink,
                  fontSize: 11 * r,
                  letterSpacing: 0.1 * r,
                  height: 1.0,
                  shadows: const [
                    Shadow(color: Color(0x55FFFFFF), offset: Offset(0, 0.7)),
                  ],
                ),
              ),
            ),
          ),
          ..._costSymbols(r),
        ],
      ),
    );
  }

  // ── aether cost symbols (iconic, never letters) ────────────────────────
  List<Widget> _costSymbols(double r) {
    final out = <Widget>[];
    if (def.type == CardType.wellspring) return out;

    Widget orb({required Widget child, required List<Color> colors,
        required Color ring}) {
      return Padding(
        padding: EdgeInsets.only(left: 2.2 * r),
        child: Container(
          width: 17 * r,
          height: 17 * r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: colors,
            ),
            border: Border.all(color: ring, width: 1.1 * r),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 2,
                  offset: Offset(0, 1)),
            ],
          ),
          child: Center(child: child),
        ),
      );
    }

    if (def.costGeneric > 0) {
      out.add(orb(
        colors: const [Color(0xFFE8EAF0), Color(0xFF9DA3B4), Color(0xFF5A6072)],
        ring: const Color(0xFF2E3240),
        child: Text('${def.costGeneric}',
            style: TextStyle(
                color: const Color(0xFF23262F),
                fontSize: 10 * r,
                fontWeight: FontWeight.w900,
                height: 1.0)),
      ));
    }
    for (final entry in def.costDominion.entries) {
      final ds = DominionStyle.of(entry.key);
      for (var i = 0; i < entry.value; i++) {
        out.add(orb(
          colors: [ds.glow, ds.orb, ds.frame[1]],
          ring: ds.frame[2],
          child: Icon(ds.icon, size: 10.5 * r, color: ds.orbText),
        ));
      }
    }
    return out;
  }

  Widget _artBox(DominionStyle style, double r) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.5 * r),
        border: Border.all(color: _goldDark, width: 1.3 * r),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/${def.id}.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _artPlaceholder(style, r),
          ),
          // inner vignette so art sits "inside" the frame
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                  ],
                  stops: const [0.72, 1.0],
                ),
              ),
            ),
          ),
          // holographic foil for Rare and above (premium sheen)
          if (def.rarity.index >= Rarity.rare.index) _foil(),
        ],
      ),
    );
  }

  /// Static holographic foil overlay. Intensity scales with rarity.
  Widget _foil() {
    final legendary = def.rarity == Rarity.legendary;
    final epic = def.rarity == Rarity.epic;
    final a = legendary ? 0.24 : (epic ? 0.20 : 0.15);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          backgroundBlendMode: BlendMode.screen,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF3D6E).withValues(alpha: a),
              const Color(0xFFFFD93D).withValues(alpha: a * 0.7),
              const Color(0xFF3DFFB0).withValues(alpha: a),
              const Color(0xFF3D9BFF).withValues(alpha: a * 0.7),
              const Color(0xFFC13DFF).withValues(alpha: a),
            ],
            stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _artPlaceholder(DominionStyle style, double r) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [style.frame[0].withValues(alpha: 0.9), style.frame[2]],
        ),
      ),
      child: Center(
        child: Icon(style.icon,
            size: 34 * r, color: style.glow.withValues(alpha: 0.75)),
      ),
    );
  }

  Widget _typeLine(DominionStyle style, double r) {
    final typeName = switch (def.type) {
      CardType.unit => 'Unit',
      CardType.rite => 'Rite',
      CardType.ritual => 'Ritual',
      CardType.sigil => 'Sigil',
      CardType.relic => 'Relic',
      CardType.wellspring => 'Wellspring',
    };
    final line = def.subtype.isEmpty ? typeName : '$typeName — ${def.subtype}';
    return Container(
      height: 17.5 * r,
      decoration: _panel(Parchment.titleTop, Parchment.titleBottom, 4 * r),
      padding: EdgeInsets.symmetric(horizontal: 6 * r),
      child: Row(
        children: [
          Icon(style.icon, size: 9.5 * r, color: style.frame[1]),
          SizedBox(width: 3.5 * r),
          Expanded(
            child: Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bodyFont.copyWith(
                    color: Parchment.ink,
                    fontSize: 8.5 * r,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2 * r,
                    height: 1.0)),
          ),
          // Instant (Rite) vs slow (Ritual) speed marker.
          if (def.type == CardType.rite)
            Padding(
              padding: EdgeInsets.only(right: 3 * r),
              child: Icon(Icons.bolt,
                  size: 9.5 * r, color: const Color(0xFF9A7010)),
            )
          else if (def.type == CardType.ritual)
            Padding(
              padding: EdgeInsets.only(right: 3 * r),
              child: Icon(Icons.hourglass_bottom,
                  size: 8.5 * r, color: _goldDark),
            ),
          if (colorblindLabels)
            Padding(
              padding: EdgeInsets.only(right: 3 * r),
              child: Text(
                switch (def.rarity) {
                  Rarity.common => 'C',
                  Rarity.uncommon => 'U',
                  Rarity.rare => 'R',
                  Rarity.epic => 'E',
                  Rarity.legendary => 'L',
                },
                style: _bodyFont.copyWith(
                    color: _goldDark,
                    fontSize: 8.5 * r,
                    fontWeight: FontWeight.w900,
                    height: 1.0),
              ),
            ),
          _rarityGem(r),
        ],
      ),
    );
  }

  Widget _rarityGem(double r) {
    // A faceted gemstone: distinct hue + shape + glow per rarity so the tier
    // reads instantly. Common is a matte stone; higher tiers gain a brighter
    // jewel and an outer glow.
    final (light, mid, dark, glow) = switch (def.rarity) {
      Rarity.common => (
          const Color(0xFFB8A88E),
          const Color(0xFF8A7358),
          const Color(0xFF57432E),
          false
        ),
      Rarity.uncommon => (
          const Color(0xFFCFE6F2),
          const Color(0xFF7FB6D4),
          const Color(0xFF3C6B86),
          false
        ),
      Rarity.rare => (
          const Color(0xFFFFF0B8),
          const Color(0xFFF2C438),
          const Color(0xFF9A7010),
          true
        ),
      Rarity.epic => (
          const Color(0xFFEDCBFF),
          const Color(0xFFC77DFF),
          const Color(0xFF6E2A9E),
          true
        ),
      Rarity.legendary => (
          const Color(0xFFFFD8A6),
          const Color(0xFFFF8A3C),
          const Color(0xFF9E3A08),
          true
        ),
    };
    final size = 13.0 * r;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: 0.785398, // 45° → gem diamond
          child: Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [light, mid, dark],
                stops: const [0, 0.5, 1],
              ),
              border: Border.all(
                  color: const Color(0xFF23180C), width: 0.8 * r),
              boxShadow: glow
                  ? [
                      BoxShadow(
                          color: mid.withValues(alpha: 0.85),
                          blurRadius: 5 * r,
                          spreadRadius: 0.5 * r)
                    ]
                  : null,
            ),
            // top-left facet highlight
            child: Align(
              alignment: const Alignment(-0.4, -0.4),
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textBox(DominionStyle style, double r) {
    final isWellspring = def.type == CardType.wellspring;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: _panel(Parchment.boxTop, Parchment.boxBottom, 5 * r),
          padding: EdgeInsets.fromLTRB(6 * r, 4.5 * r, 6 * r, 4 * r),
          child: isWellspring
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22 * r,
                      height: 22 * r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          style.glow.withValues(alpha: 0.55),
                          style.orb.withValues(alpha: 0.25),
                          Colors.transparent,
                        ]),
                        border: Border.all(
                            color: style.frame[1], width: 1.2 * r),
                      ),
                      child: Icon(style.icon,
                          size: 12 * r, color: style.frame[2]),
                    ),
                    if (def.flavor.isNotEmpty) ...[
                      SizedBox(height: 4 * r),
                      Text(def.flavor,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyFont.copyWith(
                              color: Parchment.inkSoft,
                              fontSize: 7 * r,
                              fontStyle: FontStyle.italic,
                              height: 1.25)),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (def.text.isNotEmpty)
                      Text(
                        def.text.replaceAll('{name}', def.name),
                        maxLines: def.flavor.isEmpty ? 5 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyFont.copyWith(
                            color: Parchment.ink,
                            fontSize: 8.2 * r,
                            height: 1.25),
                      ),
                    if (def.text.isNotEmpty && def.flavor.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3 * r),
                        child: Container(
                          height: 0.8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _goldDark.withValues(alpha: 0.55),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                    if (def.flavor.isNotEmpty)
                      Expanded(
                        child: Text(def.flavor,
                            overflow: TextOverflow.fade,
                            style: _bodyFont.copyWith(
                                color: Parchment.inkSoft,
                                fontSize: 7.4 * r,
                                fontStyle: FontStyle.italic,
                                height: 1.28)),
                      ),
                  ],
                ),
        ),
        if (def.type == CardType.unit)
          Positioned(right: -3 * r, bottom: -3 * r, child: _statBadge(r)),
      ],
    );
  }

  /// Sword / shield gem badge for Might / Guard.
  Widget _statBadge(double r) {
    final m = (def.might ?? 0) + plusCounters;
    final g = (def.guard ?? 0) + plusCounters - damage;
    final hurt = damage > 0;
    final buffed = plusCounters > 0;
    final guardColor =
        hurt ? AppTheme.danger : (buffed ? const Color(0xFF2E6B2A) : Parchment.ink);
    final mightColor = buffed ? const Color(0xFF2E6B2A) : Parchment.ink;

    Widget stat(IconData icon, String value, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 8.5 * r, color: _goldDark),
            SizedBox(width: 1.5 * r),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 10.5 * r,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
          ],
        );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * r, vertical: 3.5 * r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_goldLight, Parchment.titleBottom],
        ),
        borderRadius: BorderRadius.circular(6 * r),
        border: Border.all(color: const Color(0xFF0D0D0B), width: 1.3 * r),
        boxShadow: const [
          BoxShadow(
              color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stat(Icons.flash_on, '$m', mightColor),
          Container(
            width: 1,
            height: 9 * r,
            margin: EdgeInsets.symmetric(horizontal: 4 * r),
            color: _goldDark.withValues(alpha: 0.6),
          ),
          stat(Icons.shield, '$g', guardColor),
        ],
      ),
    );
  }
}
