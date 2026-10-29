import 'package:flutter/material.dart';
import 'battle_room_catalog.dart';
import 'battle_room_selection.dart';

/// A single static texture, isolated from health/hand/turn repaints. Explicit
/// rooms are used only by previews; they never change the equipped selection.
class BattleRoomBackground extends StatelessWidget {
  final BattleRoom? room;
  const BattleRoomBackground({super.key, this.room});

  static ImageProvider<Object> imageProvider(BattleRoom room) => ResizeImage(
    AssetImage(room.asset),
    width: BattleRooms.decodeWidth,
    allowUpscaling: false,
  );

  @override
  Widget build(BuildContext context) => room != null
      ? _surface(room!)
      : ValueListenableBuilder<BattleRoom>(
          valueListenable: BattleRoomSelection.active,
          builder: (_, selected, _) => _surface(selected),
        );

  Widget _surface(BattleRoom selected) => RepaintBoundary(
    key: ValueKey('battle-room-${selected.id}'),
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: imageProvider(selected),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF151B22)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x6B0B0D12),
                    const Color(
                      0xFF0B0D12,
                    ).withValues(alpha: selected.centerShade),
                    const Color(0x8C0B0D12),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
