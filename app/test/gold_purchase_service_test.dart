import 'package:flutter_test/flutter_test.dart';

import 'package:shardfall/services/purchase_catalog.dart';

void main() {
  test('exposes the closed-test Play product catalog', () {
    expect(PurchaseCatalog.gold500Id, 'gold_500');
    expect(PurchaseCatalog.gold500Amount, 500);
    expect(PurchaseCatalog.productIds, contains('gold_500'));
  });
}
