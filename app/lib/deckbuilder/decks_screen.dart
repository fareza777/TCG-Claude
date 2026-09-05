import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../services/ad_service.dart';
import '../services/audio_manager.dart';
import '../services/haptics.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/ad_banner.dart';
import 'deck_builder_screen.dart';

/// The decks a player has saved.
///
/// This did not exist. DECKS opened a blank builder, so a saved deck could
/// never be listed, reopened or deleted — the only place one was ever visible
/// again was the PvP deck picker. A player reported all three as one bug, and
/// they were right: decks were write-only.
class DecksScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  final AdService adService;

  const DecksScreen({
    super.key,
    required this.library,
    required this.save,
    required this.adService,
  });

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  SaveService get save => widget.save;

  List<String> get _names => save.decks.keys.toList()..sort();

  /// The Dominions a deck actually plays, for the colour pips.
  ///
  /// Unknown ids are skipped rather than looked up: `library.card` throws on
  /// one, decks come out of a save file, and a single retired card id would
  /// otherwise take down the whole list -- leaving the player unable to reach
  /// the deck to delete it, which is the one thing they would need to do.
  List<Dominion> _dominionsOf(List<String> cardIds) {
    final found = <Dominion>{};
    for (final id in cardIds) {
      final def = widget.library.byId[id];
      if (def == null) continue;
      for (final d in def.dominions) {
        if (d != Dominion.neutral) found.add(d);
      }
    }
    final ordered = found.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return ordered;
  }

  Future<void> _open([String? name]) async {
    Haptics.select();
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => DeckBuilderScreen(
        library: widget.library,
        save: save,
        adService: widget.adService,
        editDeck: name,
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _delete(String name) async {
    Haptics.select();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Delete this deck?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
            '"$name" will be gone for good. The cards stay in your '
            'collection.',
            style: const TextStyle(color: AppTheme.textMuted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirmed != true) return;

    await save.deleteDeck(name);
    if (!mounted) return;
    AudioManager.instance.tap();
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Deleted "$name".')));
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      bottomNavigationBar: AdBanner(adService: widget.adService),
      appBar: AppBar(
        title: const Text('DECKS'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        backgroundColor: const Color(0xFFC9A86A),
        foregroundColor: const Color(0xFF1C1508),
        icon: const Icon(Icons.add),
        label: const Text('NEW DECK',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
      body: names.isEmpty ? _empty() : _list(names),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style_outlined,
                  size: 44, color: AppTheme.textMuted),
              const SizedBox(height: 14),
              const Text('No decks yet',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Build one of ${DeckBuilderScreen.minDeck} cards or more to '
                'play it in PvP. If you are not sure where to start, the '
                'builder can assemble one from the cards you own.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );

  Widget _list(List<String> names) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: names.length,
        itemBuilder: (_, i) {
          final name = names[i];
          final cards = save.decks[name]!;
          final legal = cards.length >= DeckBuilderScreen.minDeck;
          final dominions = _dominionsOf(cards);

          return Semantics(
            button: true,
            label: '$name, ${cards.length} cards'
                '${legal ? '' : ', too few to play'}',
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: legal
                        ? AppTheme.panelBorder
                        : AppTheme.danger.withValues(alpha: 0.55)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(name),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                for (final d in dominions) ...[
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: DominionStyle.of(d).glow),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  legal
                                      ? '${cards.length} cards'
                                      : '${cards.length} cards — needs '
                                          '${DeckBuilderScreen.minDeck}',
                                  style: TextStyle(
                                      color: legal
                                          ? AppTheme.textMuted
                                          : AppTheme.danger,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Delete $name',
                        child: IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(name),
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.textMuted, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
