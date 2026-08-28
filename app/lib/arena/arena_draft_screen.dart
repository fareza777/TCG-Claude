import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/audio_manager.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';
import 'arena_draft.dart';

/// Pick your two dominions, then build a deck one card at a time.
///
/// Pops the finished 40-card list, or null if the player backs out — the caller
/// is responsible for refunding the entry fee in that case.
class ArenaDraftScreen extends StatefulWidget {
  final CardLibrary library;
  const ArenaDraftScreen({super.key, required this.library});

  @override
  State<ArenaDraftScreen> createState() => _ArenaDraftScreenState();
}

class _ArenaDraftScreenState extends State<ArenaDraftScreen> {
  final _rng = Random();
  late List<List<Dominion>> _pairs;
  ArenaDraft? _draft;

  @override
  void initState() {
    super.initState();
    _pairs = ArenaDraft.rollPairs(_rng);
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
  String _pairName(List<Dominion> p) =>
      p.map((d) => _cap(d.name)).join(' · ');

  Color _colourOf(Dominion d) => switch (d) {
        Dominion.verdance => const Color(0xFF4FB477),
        Dominion.pyre => const Color(0xFFE06C3B),
        Dominion.tide => const Color(0xFF3D9BE0),
        Dominion.dawn => const Color(0xFFE3B341),
        Dominion.gloom => const Color(0xFF9B6BD1),
        Dominion.neutral => AppTheme.textMuted,
      };

  void _choosePair(List<Dominion> pair) {
    AudioManager.instance.tap();
    setState(() {
      _draft = ArenaDraft(library: widget.library, dominions: pair, rng: _rng);
    });
  }

  void _take(CardDef card) {
    final draft = _draft!;
    AudioManager.instance.tap();
    setState(() => draft.take(card));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
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
              _header(draft),
              Expanded(
                child: draft == null ? _pairView() : _pickView(draft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ArenaDraft? draft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          ),
          Text(draft == null ? 'Choose your colours' : 'Draft',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          if (draft != null)
            Text('${draft.picked.length} / ${ArenaDraft.picks}',
                style: const TextStyle(
                    color: Color(0xFFE3B341),
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // ── step one: the run's two dominions ─────────────────────────────────
  Widget _pairView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        const Text(
          'A run is locked to two dominions. Aether is paid in matching '
          'colours, so this choice decides everything you will be offered.',
          style: TextStyle(
              color: AppTheme.textMuted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        for (final pair in _pairs) ...[
          GestureDetector(
            onTap: () => _choosePair(pair),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [
                  _colourOf(pair.first).withValues(alpha: 0.35),
                  _colourOf(pair.last).withValues(alpha: 0.35),
                ]),
                border: Border.all(
                    color: _colourOf(pair.first).withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  for (final d in pair) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _colourOf(d)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const SizedBox(width: 4),
                  Text(_pairName(pair),
                      style: const TextStyle(
                          fontFamily: 'Cinzel',
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── step two: twenty-four picks ───────────────────────────────────────
  Widget _pickView(ArenaDraft draft) {
    if (draft.isComplete) return _reviewView(draft);

    final golden = draft.pickNumber % ArenaDraft.goldenPickEvery == 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            children: [
              Text(
                golden ? 'Pick ${draft.pickNumber} — a rare is guaranteed'
                    : 'Pick ${draft.pickNumber}',
                style: TextStyle(
                    color: golden
                        ? const Color(0xFFE3B341)
                        : AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              for (final entry in draft.wellspringSplit().entries) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _colourOf(entry.key)),
                ),
                const SizedBox(width: 4),
                Text('${entry.value}',
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final card in draft.offer)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => _take(card),
                        // Drafting blind is a bad decision, not a hard one:
                        // 132px is too small to read a card's text.
                        onLongPress: () => showCardZoom(context, card),
                        child: CardWidget(def: card, width: 132),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _curveStrip(draft),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
          child: Row(
            children: [
              Text(
                'Tap to draft it. Hold to read it.',
                style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.8),
                    fontSize: 12),
              ),
              const Spacer(),
              if (draft.picked.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'Review the cards drafted so far',
                  child: GestureDetector(
                    onTap: () => _showPicked(draft),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 14, color: Color(0xFFC9A86A)),
                      const SizedBox(width: 5),
                      Text('${draft.picked.length} drafted',
                          style: const TextStyle(
                              color: Color(0xFFC9A86A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The curve of what has been drafted so far.
  ///
  /// A draft is a run of small decisions whose only shared context is the pile
  /// already built. Without this the player picks number nineteen with no idea
  /// they have taken six five-drops and nothing that costs two.
  Widget _curveStrip(ArenaDraft draft) {
    final buckets = List<int>.filled(8, 0);
    for (final card in draft.picked) {
      if (card.type == CardType.wellspring) continue;
      buckets[card.totalCost.clamp(0, 7)] += 1;
    }
    final peak = buckets.fold(1, (a, b) => b > a ? b : a);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var cost = 1; cost < 8; cost++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${buckets[cost]}',
                        style: TextStyle(
                            color: buckets[cost] == 0
                                ? AppTheme.textMuted.withValues(alpha: 0.4)
                                : AppTheme.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Container(
                      height: 4 + 22 * (buckets[cost] / peak),
                      decoration: BoxDecoration(
                        color: buckets[cost] == 0
                            ? AppTheme.panelBorder
                            : const Color(0xFFC9A86A).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(cost == 7 ? '7+' : '$cost',
                        style: TextStyle(
                            color: AppTheme.textMuted.withValues(alpha: 0.75),
                            fontSize: 9)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Everything drafted so far, grouped by name and ordered by cost.
  Future<void> _showPicked(ArenaDraft draft) async {
    AudioManager.instance.tap();
    final counts = <String, int>{};
    final defs = <String, CardDef>{};
    for (final card in draft.picked) {
      counts[card.name] = (counts[card.name] ?? 0) + 1;
      defs[card.name] = card;
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final ca = defs[a]!.totalCost;
        final cb = defs[b]!.totalCost;
        return ca != cb ? ca.compareTo(cb) : a.compareTo(b);
      });

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DRAFTED - ${draft.picked.length}',
                  style: const TextStyle(
                      color: Color(0xFFC9A86A),
                      fontSize: 13,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: names.length,
                  itemBuilder: (_, i) {
                    final def = defs[names[i]]!;
                    final n = counts[names[i]]!;
                    return GestureDetector(
                      onTap: () => showCardZoom(context, def),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _colourOf(def.dominions.first)
                                    .withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('${def.totalCost}',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(names[i],
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13)),
                            ),
                            if (n > 1)
                              Text('x$n',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text('Tap a card to read it.',
                  style: TextStyle(
                      color: AppTheme.textMuted.withValues(alpha: 0.8),
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  // ── step three: confirm ───────────────────────────────────────────────
  Widget _reviewView(ArenaDraft draft) {
    final deck = draft.buildDeck();
    final byName = <String, int>{};
    for (final c in draft.picked) {
      byName[c.name] = (byName[c.name] ?? 0) + 1;
    }
    final names = byName.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
          child: Row(
            children: [
              Text('${deck.length} cards',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text(
                  '${ArenaDraft.wellspringCount} Wellsprings added '
                  '(${draft.wellspringSplit().entries.map((e) => "${e.value} ${_cap(e.key.name)}").join(", ")})',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: names.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${byName[names[i]]}×',
                        style: const TextStyle(
                            color: Color(0xFFE3B341),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: Text(names[i],
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: GestureDetector(
            onTap: () {
              AudioManager.instance.tap();
              Navigator.of(context).pop(deck);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.danger,
                  AppTheme.danger.withValues(alpha: 0.6),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('ENTER THE GAUNTLET',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
