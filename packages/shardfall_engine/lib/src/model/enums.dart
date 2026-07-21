/// Core enumerations for SHARDFALL.
library;

enum Dominion { verdance, pyre, tide, dawn, gloom, neutral }

enum CardType { unit, rite, ritual, sigil, relic, wellspring }

enum Rarity { common, uncommon, rare, epic, legendary }

enum Keyword {
  soar,
  intercept,
  rush,
  alert,
  swiftstrike,
  venom,
  rampage,
  leech,
  dread,
  bulwark,
  ambush,
  aegis, // carries a value (Aegis N) via CardDef.aegisValue
}

enum Zone { deck, hand, arena, ruins, voidZone, chain }

enum Phase { refresh, draw, main1, combat, main2, end }

enum PlayerId { p1, p2 }

extension PlayerIdX on PlayerId {
  PlayerId get opponent => this == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
}
