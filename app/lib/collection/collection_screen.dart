import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';

/// The player's binder: owned cards in color, unowned locked in shadow.
class CollectionScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;

  const CollectionScreen(
      {super.key, required this.library, required this.save});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Dominion? _filter;
  bool _ownedOnly = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final cards = widget.library.byId.values
        .where((d) => _filter == null || d.dominions.contains(_filter))
        .where((d) => !_ownedOnly || widget.save.copiesOf(d.id) > 0)
        .where((d) =>
            q.isEmpty ||
            d.name.toLowerCase().contains(q) ||
            d.subtype.toLowerCase().contains(q) ||
            d.text.toLowerCase().contains(q))
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('Collection',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const Spacer(),
                    Text(
                        '${widget.save.uniqueOwned}/${widget.library.byId.length} owned',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _ownedOnly = !_ownedOnly),
                      child: Icon(
                        _ownedOnly
                            ? Icons.visibility
                            : Icons.visibility_outlined,
                        size: 18,
                        color: _ownedOnly
                            ? const Color(0xFFC9A86A)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppTheme.textMuted),
                    hintText: 'Search cards…',
                    hintStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppTheme.panelBorder.withValues(alpha: 0.6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppTheme.panelBorder.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip(null, 'All', Icons.grid_view,
                        const Color(0xFFC9A86A)),
                    for (final d in const [
                      Dominion.verdance,
                      Dominion.pyre,
                      Dominion.tide,
                      Dominion.dawn,
                      Dominion.gloom,
                    ])
                      _chip(d, d.name[0].toUpperCase() + d.name.substring(1),
                          DominionStyle.of(d).icon, DominionStyle.of(d).glow),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    childAspectRatio: 63 / 88,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, i) {
                    final def = cards[i];
                    final copies = widget.save.copiesOf(def.id);
                    final owned = copies > 0;
                    return GestureDetector(
                      onTap: () => showCardZoom(context, def),
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: owned ? 1 : 0.35,
                            child: ColorFiltered(
                              colorFilter: owned
                                  ? const ColorFilter.mode(
                                      Colors.transparent, BlendMode.dst)
                                  : const ColorFilter.matrix([
                                      0.3, 0.3, 0.3, 0, 0, //
                                      0.3, 0.3, 0.3, 0, 0,
                                      0.3, 0.3, 0.3, 0, 0,
                                      0, 0, 0, 1, 0,
                                    ]),
                              child: CardWidget(def: def, width: 120),
                            ),
                          ),
                          if (owned)
                            Positioned(
                              top: 3,
                              left: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0x88C9A86A)),
                                ),
                                child: Text('×$copies',
                                    style: const TextStyle(
                                        color: Color(0xFFE6CE96),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800)),
                              ),
                            )
                          else
                            const Positioned(
                              top: 5,
                              left: 5,
                              child: Icon(Icons.lock,
                                  size: 13, color: Color(0x88FFFFFF)),
                            ),
                        ],
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

  Widget _chip(Dominion? d, String label, IconData icon, Color color) {
    final selected = _filter == d;
    return GestureDetector(
      onTap: () => setState(() => _filter = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? color
                  : AppTheme.panelBorder.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? color : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

}
