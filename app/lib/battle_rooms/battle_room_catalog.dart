/// Cosmetic identities are shared by storage, shop previews and every duel.
class BattleRoom {
  final String id, name, description, asset;
  final int goldCost, accent;
  final double centerShade;
  const BattleRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.asset,
    required this.goldCost,
    required this.accent,
    this.centerShade = 0.16,
  });
  bool get isPremium => goldCost > 0;
}

abstract final class BattleRooms {
  static const classic = BattleRoom(
    id: 'classic',
    name: 'Shardstone Commons',
    description: 'Lantern light falls across a timeworn dueling courtyard.',
    asset: 'assets/ui/battle_room_classic.webp',
    goldCost: 0,
    accent: 0xFFC9A86A,
    centerShade: 0.29,
  );
  static const premium = [
    BattleRoom(
      id: 'moonroot',
      name: 'Moonroot Sanctuary',
      description: 'Keep your vows beneath moonlit roots and living bronze.',
      asset: 'assets/ui/battle_room_moonroot.webp',
      goldCost: 600,
      accent: 0xFF8BC8AD,
      centerShade: 0.18,
    ),
    BattleRoom(
      id: 'emberforge',
      name: 'Emberforge Bastion',
      description: 'A ring of dark iron above the banked fires of Ashmar.',
      asset: 'assets/ui/battle_room_emberforge.webp',
      goldCost: 600,
      accent: 0xFFE7A16D,
      centerShade: 0.12,
    ),
    BattleRoom(
      id: 'tideglass',
      name: 'Tideglass Observatory',
      description: 'Chart your next move above a sea of reflected stars.',
      asset: 'assets/ui/battle_room_tideglass.webp',
      goldCost: 600,
      accent: 0xFF8ABDD5,
      centerShade: 0.12,
    ),
  ];
  static const all = [classic, ...premium];
  // One small decoded texture per battle; previews share this cache entry.
  static const decodeWidth = 1024;
  static const thumbnailWidth = 480;
  static BattleRoom? find(String id) {
    for (final room in all) {
      if (room.id == id) return room;
    }
    return null;
  }
}

enum RoomPurchaseResult {
  purchased,
  alreadyOwned,
  insufficientGold,
  invalidRoom,
  busy,
  storageFailed,
}
