import 'package:flutter/material.dart';
import '../theme.dart';
import 'card_catalog.dart';

/// Horizontally scrolls on narrow phones so every set name stays readable.
class CardSetFilter extends StatelessWidget {
  const CardSetFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.includeAll = true,
  });
  final CardSet? selected;
  final ValueChanged<CardSet?> onChanged;
  final bool includeAll;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        if (includeAll) _chip(null, 'All sets'),
        for (final set in CardSet.values) _chip(set, set.title),
      ],
    ),
  );

  Widget _chip(CardSet? set, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == set,
      onSelected: (_) => onChanged(set),
      selectedColor: const Color(0xFF50422E),
      backgroundColor: AppTheme.panel,
      labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
    ),
  );
}

class CardSetBadge extends StatelessWidget {
  const CardSetBadge({super.key, required this.cardId});
  final String cardId;

  @override
  Widget build(BuildContext context) {
    final set = CardSet.of(cardId);
    if (set == null) return const SizedBox.shrink();
    return Tooltip(
      message: set.title,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xE6101320),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          set.code,
          style: const TextStyle(
            color: Color(0xFFE6CE96),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
