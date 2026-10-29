import 'package:flutter/foundation.dart';
import 'battle_room_catalog.dart';

/// Like the existing audio/motion preferences, appearance is device-local
/// presentation. The rules engine and online game state never read it.
abstract final class BattleRoomSelection {
  static final active = ValueNotifier<BattleRoom>(BattleRooms.classic);
}
