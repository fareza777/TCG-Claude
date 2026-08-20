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
      listenable: purchaseService,
      builder: (context, _) {
        final owned = save.removeAds;
        final busy =
            purchaseService.state == RemoveAdsPurchaseState.purchasing ||
            purchaseService.state == RemoveAdsPurchaseState.pending;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.panelBorder),
          ),
          child: ListTile(
            leading: Icon(
              owned ? Icons.block : Icons.no_adult_content,
              color: owned ? const Color(0xFF7FE0A8) : const Color(0xFFC9A86A),
            ),
            title: Text(
              owned ? 'Ads removed' : 'Remove Ads',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              owned
                  ? 'This account is ad-free on every linked device.'
                  : 'One-time purchase · ${purchaseService.priceLabel}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            trailing: owned
                ? TextButton(
                    key: const ValueKey('remove-ads-restore'),
                    onPressed: purchaseService.restorePurchases,
                    child: const Text('Restore'),
                  )
                : TextButton(
                    key: const ValueKey('remove-ads-buy'),
                    onPressed: purchaseService.canBuy
                        ? purchaseService.buyRemoveAds
                        : null,
                    child: Text(busy ? 'Processing…' : 'BUY'),
                  ),
          ),
        );
      },
    );
  }
}
