import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ad_service.dart';

/// A bounded, failure-safe banner used only on approved non-gameplay screens.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.adService});

  final AdService adService;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  AdBannerHandle? _handle;
  Timer? _retryTimer;
  bool _loading = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    widget.adService.addListener(_onServiceChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted ||
        !widget.adService.adsEnabled ||
        _loading ||
        _handle != null) {
      return;
    }
    _loading = true;
    final loaded = await widget.adService.loadBanner();
    _loading = false;

    if (!mounted) {
      loaded?.dispose();
      return;
    }
    if (!widget.adService.adsEnabled) {
      loaded?.dispose();
      return;
    }
    if (loaded == null) {
      _scheduleRetry();
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    setState(() => _handle = loaded);
  }

  void _onServiceChanged() {
    if (!widget.adService.adsEnabled) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _handle?.dispose();
      if (mounted) setState(() => _handle = null);
      return;
    }
    if (_handle == null) unawaited(_load());
    if (mounted) setState(() {});
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryCount >= 3 || !mounted) return;
    _retryCount++;
    _retryTimer = Timer(Duration(seconds: 5 * _retryCount), () {
      _retryTimer = null;
      unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (!widget.adService.adsEnabled || handle == null) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('ad-banner'),
      alignment: Alignment.center,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 3),
      color: Colors.black.withValues(alpha: 0.12),
      child: SizedBox(
        width: handle.width.toDouble(),
        height: handle.height.toDouble(),
        child: handle.buildWidget(),
      ),
    );
  }

  @override
  void dispose() {
    widget.adService.removeListener(_onServiceChanged);
    _retryTimer?.cancel();
    _handle?.dispose();
    super.dispose();
  }
}
