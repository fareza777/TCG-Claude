import 'package:shardfall_engine/shardfall_engine.dart';

abstract final class DeckRules {
  static const minimum = 40;
  static const maximum = 60;
  static const maximumWellsprings = 20;
  static int maximumCopies(CardDef card) => card.type == CardType.wellspring
      ? maximumWellsprings
      : card.rarity == Rarity.legendary
      ? 1
      : 3;
}
