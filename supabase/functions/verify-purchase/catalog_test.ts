import { PLAY_PRODUCTS } from "../_shared/purchase_catalog.ts";

Deno.test("remove_ads is a non-consumable entitlement", () => {
  const product = PLAY_PRODUCTS.remove_ads;
  if (product.goldAmount !== null || product.entitlementId !== "remove_ads") {
    throw new Error("remove_ads catalog contract changed");
  }
});

Deno.test("gold_500 keeps the existing 500 Gold grant", () => {
  const product = PLAY_PRODUCTS.gold_500;
  if (product.goldAmount !== 500 || product.entitlementId !== null) {
    throw new Error("gold_500 catalog contract changed");
  }
});
