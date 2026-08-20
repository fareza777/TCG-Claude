import 'package:flutter/material.dart';

import '../services/ad_service.dart';
import '../theme.dart';

/// Google-required entry point for reviewing or withdrawing ad consent.
class PrivacyOptionsTile extends StatelessWidget {
  const PrivacyOptionsTile({super.key, required this.ads});

  final AdService ads;

  @override
  Widget build(BuildContext context) {
    if (!ads.privacyOptionsRequired) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF9FB2BC)),
      title: const Text(
        'Privacy choices',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      ),
      subtitle: const Text(
        'Review your advertising consent',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
      onTap: ads.showPrivacyOptions,
    );
  }
}
