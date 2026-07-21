import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';

/// The Forge — craft cards with Shards, or disenchant duplicates for Shards.
class ForgeScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;

  const ForgeScreen({super.key, required this.library, required this.save});

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  Dominion? _filter;

  @override
  Widget build(BuildContext context) {
    final cards = widget.library.byId.values
        .where((d) => d.type != CardType.wellspring)
        .where((d) => _filter == null || d.dominions.contains(_filter))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

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
                    ),
                    const Text('The Forge',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    ListenableBuilder(
                      listenable: widget.save,
                      builder: (_, _) => Row(
                        children: [
                          const Icon(Icons.hexagon,
                              color: Color(0xFF8FE3FF), size: 16),
                          const SizedBox(width: 5),
                          Text('${widget.save.shards}',
                              style: const TextStyle(
                                  color: Color(0xFFCFEFFF),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    'Tap a card to craft with Shards, or disenchant duplicates.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              SizedBox(height: 40, child: _filterBar()),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    childAspectRatio: 63 / 88,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, i) => _forgeCard(cards[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _forgeCard(CardDef def) {
    final copies = widget.save.copiesOf(def.id);
    final owned = copies > 0;
    return GestureDetector(
      onTap: () => _openForgeDialog(def),
      child: Stack(
        children: [
          Opacity(
            opacity: owned ? 1 : 0.5,
            child: CardWidget(def: def, width: 112),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x668FE3FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hexagon,
                      size: 8, color: Color(0xFF8FE3FF)),
                  const SizedBox(width: 3),
                  Text('${SaveService.craftCost[def.rarity]}',
                      style: const TextStyle(
                          color: Color(0xFFCFEFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          if (owned)
            Positioned(
              top: 3,
              left: 3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('×$copies',
                    style: const TextStyle(
                        color: Color(0xFFE6CE96),
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  void _openForgeDialog(CardDef def) {
    showDialog<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: widget.save,
        builder: (context, _) {
          final craftC = SaveService.craftCost[def.rarity]!;
          final disC = SaveService.disenchantValue[def.rarity]!;
          final copies = widget.save.copiesOf(def.id);
          final canCraft = widget.save.canCraft(def);
          final canDis = widget.save.canDisenchant(def);
          final atMax = copies >= widget.save.maxCopies(def.rarity);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardWidget(def: def, width: 200),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Owned: $copies / ${widget.save.maxCopies(def.rarity)}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _forgeBtn(
                            label: atMax ? 'Max copies' : 'Craft ($craftC◈)',
                            color: const Color(0xFF8FE3FF),
                            enabled: canCraft,
                            onTap: () async {
                              if (await widget.save.craftCard(def)) {
                                AudioManager.instance.reward();
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          _forgeBtn(
                            label: 'Disenchant (+$disC◈)',
                            color: const Color(0xFFC9A86A),
                            enabled: canDis,
                            onTap: () async {
                              await widget.save.disenchantCard(def);
                              AudioManager.instance.tap();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _forgeBtn({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _filterBar() {
    Widget chip(Dominion? d, String label, IconData icon, Color color) {
      final sel = _filter == d;
      return GestureDetector(
        onTap: () => setState(() => _filter = d),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? color.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel
                    ? color
                    : AppTheme.panelBorder.withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: sel ? color : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : AppTheme.textMuted,
                    fontSize: 12)),
          ]),
        ),
      );
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        chip(null, 'All', Icons.grid_view, const Color(0xFFC9A86A)),
        for (final d in const [
          Dominion.verdance,
          Dominion.pyre,
          Dominion.tide,
          Dominion.dawn,
          Dominion.gloom,
        ])
          chip(d, d.name[0].toUpperCase() + d.name.substring(1),
              DominionStyle.of(d).icon, DominionStyle.of(d).glow),
      ],
    );
  }
}
