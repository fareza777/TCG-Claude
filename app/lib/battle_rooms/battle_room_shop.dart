import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import '../services/ad_service.dart';
import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';
import '../widgets/ad_banner.dart';
import 'battle_room_background.dart';
import 'battle_room_catalog.dart';
import 'battle_room_preview.dart';

class BattleRoomShopScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  final AdService adService;
  const BattleRoomShopScreen({
    super.key,
    required this.library,
    required this.save,
    required this.adService,
  });
  @override
  State<BattleRoomShopScreen> createState() => _BattleRoomShopState();
}

class _BattleRoomShopState extends State<BattleRoomShopScreen> {
  bool _busy = false;
  SaveService get save => widget.save;

  Future<void> _act(BattleRoom room) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String message;
      if (!save.ownedBattleRooms.contains(room.id)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.panel,
            title: Text(
              'Unlock ${room.name}?',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            content: Text(
              'Spend ${room.goldCost} Gold to own this room permanently and equip it for every battle.',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                key: const ValueKey('confirm-room-purchase'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('BUY & EQUIP · ${room.goldCost} GOLD'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final result = await save.purchaseBattleRoom(room.id);
        message = switch (result) {
          RoomPurchaseResult.purchased => '${room.name} unlocked and equipped.',
          RoomPurchaseResult.insufficientGold =>
            'You need more Gold for this room.',
          RoomPurchaseResult.storageFailed =>
            'Could not save the room. Your Gold was returned.',
          RoomPurchaseResult.alreadyOwned => 'You already own this room.',
          _ => 'The room could not be equipped. Please try again.',
        };
        if (result == RoomPurchaseResult.purchased) {
          AudioManager.instance.reward();
        }
      } else {
        final equipped = await save.equipBattleRoom(room.id);
        message = equipped
            ? '${room.name} equipped.'
            : 'Could not save your room selection.';
      }
      if (!mounted) return;
      unawaited(
        precacheImage(
          BattleRoomBackground.imageProvider(room),
          context,
          onError: (_, _) {},
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview(BattleRoom room) {
    AudioManager.instance.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleRoomPreview(room: room, library: widget.library),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: save,
    builder: (_, _) => Scaffold(
      backgroundColor: AppTheme.bgBottom,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBottom,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'BATTLE ROOMS',
          style: TextStyle(fontSize: 16, letterSpacing: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFE3B341),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${save.gold}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdBanner(adService: widget.adService),
      body: LayoutBuilder(
        builder: (_, bounds) {
          final contentWidth = bounds.maxWidth.clamp(0.0, 1120.0);
          final columns = contentWidth >= 700 ? 2 : 1;
          final cardWidth = (contentWidth - 32 - (columns - 1) * 16) / columns;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: SizedBox(
                  width: 1088,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A PLACE FOR YOUR NEXT VOW',
                        style: TextStyle(
                          color: Color(0xFFC9A86A),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Choose your ground.',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: AppTheme.textPrimary,
                          fontSize: 25,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Unlock a room once and use it in every mode. Your cards and rules stay the same.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 16,
                        runSpacing: 18,
                        children: [
                          for (final room in BattleRooms.all)
                            SizedBox(width: cardWidth, child: _roomCard(room)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _roomCard(BattleRoom room) {
    final owned = save.ownedBattleRooms.contains(room.id);
    final equipped = save.equippedBattleRoom == room.id;
    final affordable = save.gold >= room.goldCost;
    final accent = Color(room.accent);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: equipped ? accent : AppTheme.panelBorder,
          width: equipped ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  room.asset,
                  fit: BoxFit.cover,
                  cacheWidth: BattleRooms.thumbnailWidth,
                  filterQuality: FilterQuality.low,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x000B0D12), Color(0xE60B0D12)],
                      stops: [0.25, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 48,
                  bottom: 13,
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Cinzel',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xDE11151E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      equipped
                          ? 'EQUIPPED'
                          : owned
                          ? 'OWNED'
                          : '${room.goldCost} GOLD',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 2,
                  child: IconButton(
                    key: ValueKey('preview-${room.id}'),
                    tooltip: 'Preview ${room.name}',
                    onPressed: _busy ? null : () => _preview(room),
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  room.description,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: ValueKey('${owned ? 'equip' : 'buy'}-${room.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF10141B),
                    disabledBackgroundColor: accent.withValues(alpha: .12),
                    disabledForegroundColor: equipped
                        ? accent
                        : AppTheme.textMuted,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _busy || equipped || (!owned && !affordable)
                      ? null
                      : () => _act(room),
                  child: Text(
                    equipped
                        ? 'IN USE'
                        : owned
                        ? 'EQUIP ROOM'
                        : affordable
                        ? 'BUY & EQUIP · ${room.goldCost} GOLD'
                        : 'Need ${room.goldCost - save.gold} more Gold',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
