export interface PlayProduct {
  goldAmount: number | null;
  entitlementId: string | null;
}

/// Keep in sync with app/lib/services/purchase_catalog.dart.
export const PLAY_PRODUCTS: Record<string, PlayProduct> = {
  gold_500: { goldAmount: 500, entitlementId: null },
  remove_ads: { goldAmount: null, entitlementId: "remove_ads" },
};
