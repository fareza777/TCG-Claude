import 'package:flutter/material.dart';

import '../services/remove_ads_purchase_service.dart';
import '../services/save_service.dart';
import '../theme.dart';

/// Compact Settings offer for the permanent Remove Ads entitlement.
class RemoveAdsOffer extends StatelessWidget {
  const RemoveAdsOffer({
    super.key,
    required this.purchaseService,
    required this.save,
  });

  final RemoveAdsPurchaseService purchaseService;
  final SaveService save;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([purchaseService, save]),
      builder: (context, _) {
        final owned = save.removeAds;
        final busy =
            purchaseService.state == RemoveAdsPurchaseState.purchasing ||
            purchaseService.state == RemoveAdsPurchaseState.pending;
        final unavailable =
            purchaseService.state == RemoveAdsPurchaseState.unavailable;
        final subtitle = owned
            ? 'This device and linked accounts stay ad-free.'
            : unavailable
            ? (purchaseService.message ??
                'Store unavailable. Restore if you already bought this.')
            : 'One-time ${purchaseService.priceLabel}. Restore if you already bought it.';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.panelBorder),
          ),
          child: Row(
            children: [
              Icon(
                owned ? Icons.check_circle_outline : Icons.block,
                color: owned
                    ? const Color(0xFF7FE0A8)
                    : const Color(0xFFC9A86A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owned ? 'Ads removed' : 'Remove Ads',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('remove-ads-restore'),
                onPressed: purchaseService.restorePurchases,
                child: const Text('Restore'),
              ),
              if (!owned)
                TextButton(
                  key: const ValueKey('remove-ads-buy'),
                  onPressed: purchaseService.canBuy
                      ? purchaseService.buyRemoveAds
                      : null,
                  child: Text(busy ? 'Processing…' : 'BUY'),
                ),
            ],
          ),
        );
      },
    );
  }
}
