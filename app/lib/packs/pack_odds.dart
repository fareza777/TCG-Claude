import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../theme.dart';

/// The Shard Pack drop table.
///
/// Google Play requires the odds of a paid randomised item to be disclosed
/// before purchase. [BoosterScreen] builds packs from these values and
/// [PackOddsSheet] reads the same ones, so what a player is shown cannot drift
/// from what the generator actually does.
abstract final class PackOdds {
  static const commonSlots = 7;
  static const uncommonSlots = 3;

  /// The last card is Legendary on a 1-in-[legendaryOneIn] roll, Rare
  /// otherwise.
  static const legendaryOneIn = 12;

  static const cardsPerPack = commonSlots + uncommonSlots + 1;

  static const legendaryChance = 1 / legendaryOneIn;
  static const rareChance = 1 - legendaryChance;

  /// Rarities a pack can never produce. Epic cards are Forge-only.
  static const unobtainable = <Rarity>[Rarity.epic];

  static String percent(double chance) =>
      '${(chance * 100).toStringAsFixed(2)}%';
}

/// Player-facing odds disclosure, reachable before any pack is bought.
class PackOddsSheet extends StatelessWidget {
  const PackOddsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const PackOddsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shard Pack odds',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Every pack contains ${PackOdds.cardsPerPack} cards.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          _row('Common', '${PackOdds.commonSlots} cards', 'guaranteed'),
          _row('Uncommon', '${PackOdds.uncommonSlots} cards', 'guaranteed'),
          const Divider(color: AppTheme.panelBorder),
          const Text('Final card',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _row('Rare', PackOdds.percent(PackOdds.rareChance), ''),
          _row('Legendary', PackOdds.percent(PackOdds.legendaryChance), ''),
          const SizedBox(height: 12),
          const Text(
              'Within a rarity, every card is equally likely. Epic cards never '
              'appear in packs — craft them in the Forge with Shards.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFF0E4C0),
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(note,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
