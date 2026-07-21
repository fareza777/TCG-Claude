import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/card_zoom.dart';

/// Build and save 40+ card decks from owned cards. Wellsprings are treated
/// as unlimited basic resources (cap 20); other cards are limited by owned
/// copies and rarity (Legendary 1, else 3).
class DeckBuilderScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  final String? editDeck;

  const DeckBuilderScreen({
    super.key,
    required this.library,
    required this.save,
    this.editDeck,
  });

  @override
  State<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends State<DeckBuilderScreen> {
  final Map<String, int> _deck = {}; // cardId -> count
  Dominion? _filter;

  static const minDeck = 40;
  static const maxDeck = 60;
  static const maxWellspring = 20;

  @override
  void initState() {
    super.initState();
    final existing = widget.editDeck;
    if (existing != null && widget.save.decks.containsKey(existing)) {
      for (final id in widget.save.decks[existing]!) {
        _deck[id] = (_deck[id] ?? 0) + 1;
      }
    }
  }

  int get _size => _deck.values.fold(0, (a, b) => a + b);
  int get _wellsprings {
    var n = 0;
    _deck.forEach((id, c) {
      if (widget.library.card(id).type == CardType.wellspring) n += c;
    });
    return n;
  }

  int _maxCopies(CardDef def) {
    if (def.type == CardType.wellspring) return maxWellspring;
    return def.rarity == Rarity.legendary ? 1 : 3;
  }

  bool _canAdd(CardDef def) {
    if (_size >= maxDeck) return false;
    final inDeck = _deck[def.id] ?? 0;
    if (inDeck >= _maxCopies(def)) return false;
    if (def.type != CardType.wellspring &&
        inDeck >= widget.save.copiesOf(def.id)) {
      return false;
    }
    return true;
  }

  void _add(CardDef def) {
    if (!_canAdd(def)) return;
    AudioManager.instance.tap();
    setState(() => _deck[def.id] = (_deck[def.id] ?? 0) + 1);
  }

  void _remove(String id) {
    AudioManager.instance.tap();
    setState(() {
      final n = (_deck[id] ?? 0) - 1;
      if (n <= 0) {
        _deck.remove(id);
      } else {
        _deck[id] = n;
      }
    });
  }

  void _autoWellspring() {
    // Fill wellsprings of the deck's dominant dominion up to 16.
    final counts = <Dominion, int>{};
    _deck.forEach((id, c) {
      for (final d in widget.library.card(id).dominions) {
        counts[d] = (counts[d] ?? 0) + c;
      }
    });
    if (counts.isEmpty) return;
    final dom =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final ws = widget.library.byId.values.firstWhere(
      (c) => c.type == CardType.wellspring && c.dominions.contains(dom),
      orElse: () => widget.library.byId.values
          .firstWhere((c) => c.type == CardType.wellspring),
    );
    setState(() => _deck[ws.id] = 16);
  }

  // ── deck code sharing ────────────────────────────────────────────────
  String _exportCode() {
    final parts = _deck.entries.map((e) => '${e.key}:${e.value}').join(';');
    return 'SF1-${base64Url.encode(utf8.encode(parts))}';
  }

  void _showExport() {
    if (_deck.isEmpty) return;
    final code = _exportCode();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Deck code',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(code,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Share this code so others can import your deck.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Deck code copied.'),
                  duration: Duration(seconds: 2)));
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImport() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Import deck code',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          decoration: const InputDecoration(hintText: 'Paste SF1-... code'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Import')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final raw = code.replaceFirst('SF1-', '');
      final parts = utf8.decode(base64Url.decode(raw)).split(';');
      final map = <String, int>{};
      for (final p in parts) {
        final kv = p.split(':');
        if (kv.length == 2 && widget.library.byId.containsKey(kv[0])) {
          map[kv[0]] = int.parse(kv[1]);
        }
      }
      if (map.isEmpty) throw const FormatException('empty');
      setState(() {
        _deck
          ..clear()
          ..addAll(map);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Deck imported.'),
            duration: Duration(seconds: 2)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Invalid deck code.'),
            duration: Duration(seconds: 2)));
      }
    }
  }

  Future<void> _save() async {
    if (_size < minDeck) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('A deck needs at least $minDeck cards (have $_size).'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final controller =
        TextEditingController(text: widget.editDeck ?? 'My Deck');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Name your deck',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Deck name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ids = <String>[];
    _deck.forEach((id, c) {
      for (var i = 0; i < c; i++) {
        ids.add(id);
      }
    });
    await widget.save.saveDeck(name, ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deck "$name" saved.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownedCards = widget.library.byId.values
        .where((d) =>
            d.type == CardType.wellspring || widget.save.copiesOf(d.id) > 0)
        .where((d) => _filter == null || d.dominions.contains(_filter))
        .toList()
      ..sort((a, b) {
        final t = a.totalCost.compareTo(b.totalCost);
        return t != 0 ? t : a.id.compareTo(b.id);
      });

    final valid = _size >= minDeck;
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
              _header(valid),
              _filterBar(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _ownedGrid(ownedCards)),
                    Container(width: 1, color: AppTheme.panelBorder),
                    Expanded(flex: 2, child: _deckList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool valid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          ),
          const Text('Deck Builder',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            tooltip: 'Import code',
            onPressed: _showImport,
            icon: const Icon(Icons.download, color: AppTheme.textMuted, size: 20),
          ),
          IconButton(
            tooltip: 'Export code',
            onPressed: _showExport,
            icon: const Icon(Icons.ios_share,
                color: AppTheme.textMuted, size: 19),
          ),
          Text('$_size',
              style: TextStyle(
                  color: valid ? const Color(0xFF7FE0A8) : AppTheme.danger,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          Text('/$minDeck  ·  ${_wellsprings}W',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: valid
                    ? const [Color(0xFFC9A86A), Color(0xFF8A713A)]
                    : [AppTheme.panelBorder, AppTheme.panel]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('SAVE',
                  style: TextStyle(
                      color: Color(0xFF1C1508),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(null, 'All', Icons.grid_view, const Color(0xFFC9A86A)),
          for (final d in const [
            Dominion.verdance,
            Dominion.pyre,
            Dominion.tide,
            Dominion.dawn,
            Dominion.gloom,
          ])
            _chip(d, d.name[0].toUpperCase() + d.name.substring(1),
                DominionStyle.of(d).icon, DominionStyle.of(d).glow),
          GestureDetector(
            onTap: _autoWellspring,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF7FE0A8).withValues(alpha: 0.6)),
              ),
              child: const Row(children: [
                Icon(Icons.water_drop,
                    size: 14, color: Color(0xFF7FE0A8)),
                SizedBox(width: 5),
                Text('Auto 16 Wells',
                    style:
                        TextStyle(color: Color(0xFF7FE0A8), fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(Dominion? d, String label, IconData icon, Color color) {
    final selected = _filter == d;
    return GestureDetector(
      onTap: () => setState(() => _filter = d),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
        child: Row(children: [
          Icon(icon, size: 14, color: selected ? color : AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _ownedGrid(List<CardDef> cards) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        childAspectRatio: 63 / 88,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final def = cards[i];
        final inDeck = _deck[def.id] ?? 0;
        final canAdd = _canAdd(def);
        return GestureDetector(
          onTap: () => _add(def),
          onLongPress: () => showCardZoom(context, def),
          child: Opacity(
            opacity: canAdd || inDeck > 0 ? 1 : 0.45,
            child: Stack(
              children: [
                CardWidget(def: def, width: 86),
                if (inDeck > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7FE0A8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$inDeck',
                          style: const TextStyle(
                              color: Color(0xFF0B2417),
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _deckList() {
    final entries = _deck.entries.toList()
      ..sort((a, b) {
        final ca = widget.library.card(a.key);
        final cb = widget.library.card(b.key);
        final t = ca.totalCost.compareTo(cb.totalCost);
        return t != 0 ? t : ca.name.compareTo(cb.name);
      });
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Tap cards on the left to add them to your deck.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final def = widget.library.card(entries[i].key);
        final count = entries[i].value;
        final style = DominionStyle.ofCard(def);
        return GestureDetector(
          onTap: () => _remove(def.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(6),
              border: Border(
                  left: BorderSide(color: style.glow, width: 3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  alignment: Alignment.center,
                  child: Text('$count',
                      style: const TextStyle(
                          color: Color(0xFFE6CE96),
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 4),
                Text('${def.totalCost}',
                    style: TextStyle(
                        color: style.glow,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(def.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12)),
                ),
                const Icon(Icons.remove_circle_outline,
                    size: 15, color: AppTheme.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
