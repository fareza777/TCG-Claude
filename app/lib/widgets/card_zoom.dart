import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../theme.dart';

/// Rules glossary shown under a zoomed card.
const Map<String, String> keywordGlossary = {
  'Soar': 'Can only be blocked by Units with Soar or Intercept.',
  'Intercept': 'Can block attackers with Soar.',
  'Rush': 'Can attack the turn it enters the Arena.',
  'Alert': 'Attacking does not exert this Unit.',
  'Swiftstrike': 'Deals its combat damage before Units without Swiftstrike.',
  'Venom': 'Any damage this deals to a Unit destroys that Unit.',
  'Rampage': 'Excess combat damage over blockers is dealt to the enemy player.',
  'Leech': 'Damage this deals also restores that much Health to you.',
  'Dread': 'Cannot be blocked by fewer than two Units.',
  'Bulwark': 'Cannot attack.',
  'Ambush': 'May block even while exerted (after it has attacked).',
  'Aegis': 'Aegis N — prevents N combat damage dealt to this Unit each combat.',
  'Exert': 'Turn a card sideways to pay a cost. It refreshes on your next turn.',
  'Rite': 'Instant spell (⚡). Cast at any time — even on the enemy\'s turn, in response.',
  'Ritual': 'Slow spell (hourglass). Cast only in your own Main phase, when the chain is empty.',
  'Wellspring': 'Your Aether source. You may place one per turn.',
};

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Codex meta + flavour lore panel shown under the zoomed card.
Widget _codexPanel(CardDef def) {
  final doms = def.dominions
      .where((d) => d != Dominion.neutral)
      .map((d) => _titleCase(d.name))
      .join('/');
  final meta = [
    _titleCase(def.rarity.name),
    if (doms.isNotEmpty) doms else 'Neutral',
    _titleCase(def.type.name),
    if (def.type == CardType.unit) '${def.might ?? 0}/${def.guard ?? 0}',
  ].join('  ·  ');

  return Container(
    width: 300,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.panel.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: rarityColor(def.rarity).withValues(alpha: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(def.name,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(meta,
            style: TextStyle(
                color: rarityColor(def.rarity), fontSize: 11, letterSpacing: 0.4)),
        if (def.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(def.text,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12, height: 1.35)),
        ],
        if (def.flavor.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(def.flavor,
              style: const TextStyle(
                  fontFamily: 'EBGaramond',
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  height: 1.4)),
        ],
      ],
    ),
  );
}

/// Show a card enlarged with tap-to-reveal keyword explanations.
void showCardZoom(BuildContext context, CardDef def) {
  final found = <String>[];
  final haystack = '${def.text} ${def.type.name}';
  for (final k in keywordGlossary.keys) {
    if (RegExp('\\b$k', caseSensitive: false).hasMatch(haystack)) {
      found.add(k);
    }
  }
  final typeName = def.type.name[0].toUpperCase() + def.type.name.substring(1);
  if (!found.contains(typeName) && keywordGlossary.containsKey(typeName)) {
    found.add(typeName);
  }

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (_) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: CardWidget(def: def, width: 290),
                ),
                const SizedBox(height: 12),
                _codexPanel(def),
                if (found.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.panel.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.panelBorder.withValues(alpha: 0.8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final k in found)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppTheme.textMuted),
                                children: [
                                  TextSpan(
                                    text: '$k — ',
                                    style: const TextStyle(
                                        color: Color(0xFFC9A86A),
                                        fontWeight: FontWeight.w800),
                                  ),
                                  TextSpan(text: keywordGlossary[k]),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text('tap anywhere to close',
                    style:
                        TextStyle(color: Color(0x669A97A8), fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
