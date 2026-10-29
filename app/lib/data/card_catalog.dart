import 'package:flutter/services.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// Set identity is encoded in stable card ids, including on older saves.
enum CardSet {
  sundering('SF001', 'The Sundering', 'assets/data/set01.json', 'SF001-281'),
  fiveVows('SF002', 'The Five Vows', 'assets/data/set02.json', 'SF002-043');

  const CardSet(this.code, this.title, this.asset, this.packArt);
  final String code;
  final String title;
  final String asset;
  final String packArt;

  bool contains(String cardId) => cardId.startsWith('$code-');

  static CardSet? of(String cardId) {
    for (final set in values) {
      if (set.contains(cardId)) return set;
    }
    return null;
  }
}

abstract final class CardCatalog {
  static Future<CardLibrary> load({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final documents = await Future.wait([
      for (final set in CardSet.values) source.loadString(set.asset),
    ]);
    return CardLibrary.fromJsonStrings(documents);
  }
}
