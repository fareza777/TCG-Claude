import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import 'pack_odds.dart';
import '../services/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/gold_purchase_service.dart';
import '../services/purchase_catalog.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';

/// Sundering Shard Pack opening. A premium foil pack (with a shine sweep) →
/// tap to open → 11 face-down cards that flip in 3D. Pulled cards join the
/// collection. Simple, robust open flow.
class BoosterScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  final GoldPurchaseService purchaseService;

  /// Real-money Gold is account-only: a receipt has to outlive the device,
  /// and only a linked account can carry it. Guests see the offer locked.
  final AuthService auth;

  const BoosterScreen(
      {super.key,
      required this.library,
      required this.save,
      required this.purchaseService,
      required this.auth});

  @override
  State<BoosterScreen> createState() => _BoosterScreenState();
}

class _BoosterScreenState extends State<BoosterScreen>
    with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  List<CardDef>? _pack;
  final Set<int> _flipped = {};
  late final AnimationController _shine;

  // A dramatic hero art shown in the pack window.
  static const _packArt = 'SF001-281';

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  List<CardDef> _pool(Rarity r) => widget.library.byId.values
      .where((c) => c.type != CardType.wellspring && c.rarity == r)
      .toList();

  Future<void> _openPack() async {
    if (_pack != null) return;
    if (!widget.save.canBuyPack) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not enough gold. Win duels and story battles!'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final commons = _pool(Rarity.common);
    final uncommons = _pool(Rarity.uncommon);
    final rares = _pool(Rarity.rare);
    final legendaries = _pool(Rarity.legendary);
    CardDef pick(List<CardDef> from) => from[_rng.nextInt(from.length)];

    final rareSlot =
        (_rng.nextInt(PackOdds.legendaryOneIn) == 0 && legendaries.isNotEmpty)
            ? pick(legendaries)
            : pick(rares);
    final pack = [
      for (var i = 0; i < PackOdds.commonSlots; i++) pick(commons),
      for (var i = 0; i < PackOdds.uncommonSlots; i++) pick(uncommons),
      rareSlot,
    ];
    final paid = await widget.save.buyPack(pack);
    if (!paid || !mounted) return;
    AudioManager.instance.cardPlay();
    setState(() {
      _flipped.clear();
      _pack = pack;
    });
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('Shard Packs',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const Spacer(),
                    ListenableBuilder(
                      listenable: widget.save,
                      builder: (_, _) => Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Color(0xFFE3B341), size: 17),
                          const SizedBox(width: 5),
                          Text('${widget.save.gold}',
                              style: const TextStyle(
                                  color: Color(0xFFF0E4C0),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _pack == null ? _sealedPack() : _openedPack(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── the foil pack ──────────────────────────────────────────────────────
  Widget _sealedPack() {
    return ListenableBuilder(
      listenable: widget.save,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 38),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openPack,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(seconds: 3),
                        curve: Curves.easeInOut,
                        builder: (context, t, child) => Transform.translate(
                          offset: Offset(0, math.sin(t * math.pi * 2) * 6),
                          child: child,
                        ),
                        child: _packBody(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                          widget.save.canBuyPack
                              ? 'Tap to tear open'
                              : 'Not enough gold — win battles to earn more',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _goldPurchasePanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _goldPurchasePanel() {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.purchaseService, widget.auth]),
      builder: (context, _) {
        final purchases = widget.purchaseService;
        final locked = !widget.auth.isSignedIn;
        final isBusy = purchases.state == GoldPurchaseState.loading ||
            purchases.state == GoldPurchaseState.purchasing ||
            purchases.state == GoldPurchaseState.pending;
        final buttonLabel = switch (purchases.state) {
          GoldPurchaseState.loading => 'Loading store...',
          GoldPurchaseState.purchasing => 'Opening Google Play...',
          GoldPurchaseState.pending => 'Waiting for confirmation...',
          _ => 'Buy ${PurchaseCatalog.gold500Amount} Gold · ${purchases.priceLabel}',
        };

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.panel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFC9A86A).withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3B341).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on,
                          color: Color(0xFFE3B341), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need more Gold?',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 3),
                          Text('Open five Shard Packs instantly.',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: !locked && purchases.canBuy && !isBusy
                        ? () {
                            AudioManager.instance.tap();
                            unawaited(purchases.buyGold());
                          }
                        : null,
                    icon: Icon(locked
                        ? Icons.lock_outline
                        : isBusy
                            ? Icons.hourglass_top
                            : Icons.shopping_bag_outlined),
                    label: Text(
                        locked ? 'Sign in to purchase Gold' : buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A86A),
                      foregroundColor: const Color(0xFF1C1508),
                      disabledBackgroundColor:
                          const Color(0xFF6D654F).withValues(alpha: 0.55),
                      disabledForegroundColor:
                          const Color(0xFFDDD5C2).withValues(alpha: 0.65),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w900),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 8),
                  const Text(
                      'Paid Gold is tied to a Google account so it survives '
                      'reinstalls. Link one from Settings to unlock this.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ] else if (purchases.message != null) ...[
                  const SizedBox(height: 8),
                  Text(purchases.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _packBody() {
    const w = 210.0;
    const h = 300.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6E4AB0).withValues(alpha: 0.4),
              blurRadius: 34,
              spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              // foil base + content laid out as a clean column
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3A2E66),
                      Color(0xFF1B2A55),
                      Color(0xFF10132E),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // top tear strip
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFC9A86A),
                          Color(0xFF8A713A),
                        ]),
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.black.withValues(alpha: 0.5),
                                width: 1)),
                      ),
                      child: Center(
                        child: Container(
                          width: w * 0.5,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // art window
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: SizedBox(
                        height: 138,
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFC9A86A), width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/art/$_packArt.webp',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppTheme.panel)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('THE SUNDERING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: Color(0xFFE6CE96),
                            fontSize: 16,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6)
                            ])),
                    const SizedBox(height: 3),
                    const Text('SHARD PACK',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                          '${PackOdds.cardsPerPack} cards · 1 Rare+ guaranteed',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFB9C2CE), fontSize: 10)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on,
                            color: Color(0xFFE3B341), size: 13),
                        const SizedBox(width: 4),
                        Text('${SaveService.packCost}',
                            style: const TextStyle(
                                color: Color(0xFFF0E4C0),
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Play policy: the odds have to be readable before buying.
                    GestureDetector(
                      onTap: () => PackOddsSheet.show(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Text('View pack odds',
                            style: TextStyle(
                                color: Color(0xFFC9A86A),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC9A86A))),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              // shine sweep (overlay, non-interactive)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shine,
                  builder: (context, _) {
                    final x = (_shine.value * 2 - 0.5) * w * 1.6 - w * 0.3;
                    return Transform.translate(
                      offset: Offset(x, 0),
                      child: Transform.rotate(
                        angle: 0.4,
                        child: Container(
                          width: 60,
                          height: h * 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── opened cards ───────────────────────────────────────────────────────
  Widget _openedPack() {
    final pack = _pack!;
    final allFlipped = _flipped.length == pack.length;
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 63 / 88,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: pack.length,
            itemBuilder: (_, i) => _FlipCard(
              def: pack[i],
              flipped: _flipped.contains(i),
              isMoneySlot: i == pack.length - 1,
              entranceDelayMs: i * 70,
              onTap: () {
                if (_flipped.contains(i)) {
                  showCardZoom(context, pack[i]);
                } else {
                  AudioManager.instance.tap();
                  if (pack[i].rarity.index >= Rarity.rare.index) {
                    AudioManager.instance.reward();
                  }
                  setState(() => _flipped.add(i));
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!allFlipped)
                TextButton(
                  onPressed: () => setState(() => _flipped
                      .addAll(List.generate(pack.length, (i) => i))),
                  child: const Text('Reveal all',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              if (allFlipped)
                GestureDetector(
                  onTap: () => setState(() => _pack = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFC9A86A), Color(0xFF8A713A)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('OPEN ANOTHER · ${SaveService.packCost}g',
                        style: const TextStyle(
                            color: Color(0xFF1C1508),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Face-down card that flips in 3D when tapped.
class _FlipCard extends StatelessWidget {
  final CardDef def;
  final bool flipped;
  final bool isMoneySlot;
  final int entranceDelayMs;
  final VoidCallback onTap;

  const _FlipCard({
    required this.def,
    required this.flipped,
    required this.isMoneySlot,
    required this.entranceDelayMs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glow = rarityColor(def.rarity);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + entranceDelayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
            offset: Offset(0, 30 * (1 - t)), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: flipped ? 1 : 0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) {
            final angle = t * math.pi;
            final showFace = t > 0.5;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: flipped && def.rarity.index >= Rarity.rare.index
                    ? [
                        BoxShadow(
                            color: glow.withValues(alpha: 0.55),
                            blurRadius: 16,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: showFace
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: LayoutBuilder(
                          builder: (context, box) =>
                              CardWidget(def: def, width: box.maxWidth),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) => CardWidget(
                            def: def, width: box.maxWidth, faceDown: true),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
