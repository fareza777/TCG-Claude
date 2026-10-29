import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import '../card_render/card_widget.dart';
import '../theme.dart';
import 'battle_room_background.dart';
import 'battle_room_catalog.dart';

/// A non-interactive composition using real cards for scale and contrast.
/// It creates no game controller, audio section, purchases or profile writes.
class BattleRoomPreview extends StatelessWidget {
  final BattleRoom room;
  final CardLibrary library;
  const BattleRoomPreview({
    super.key,
    required this.room,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    final units = library.byId.values
        .where((c) => c.type == CardType.unit)
        .toList();
    final samples = [
      for (final id in ['SF002-093', 'SF002-177', 'SF002-004', 'SF002-138'])
        library.byId[id] ?? units.first,
    ];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          BattleRoomBackground(room: room),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close preview',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ROOM PREVIEW',
                              style: TextStyle(
                                color: Color(room.accent),
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              room.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Cinzel',
                                fontSize: 17,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, bounds) {
                      final width = math.min(
                        118.0,
                        math.min(
                          bounds.maxWidth * .25,
                          bounds.maxHeight * .34 / 1.45,
                        ),
                      );
                      Widget row(int start) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CardWidget(def: samples[start], width: width),
                          const SizedBox(width: 14),
                          CardWidget(def: samples[start + 1], width: width),
                        ],
                      );
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          row(0),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 36),
                            color: Color(room.accent).withValues(alpha: .3),
                          ),
                          row(2),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: [
                      Text(
                        room.isPremium
                            ? '${room.goldCost} Gold · Cosmetic room'
                            : 'Free default room',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Color(room.accent)),
                        ),
                        child: const Text('BACK TO BATTLE ROOMS'),
                      ),
                    ],
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
