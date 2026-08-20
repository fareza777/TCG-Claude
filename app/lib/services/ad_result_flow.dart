import 'ad_service.dart';

/// Shows a prepared interstitial only after a result has returned the player
/// to a safe, non-gameplay screen. Missing services and unavailable ads are
/// intentionally treated as a normal no-op.
Future<bool> showPostResultInterstitial(AdService? adService) async {
  return adService?.showInterstitialIfEligible() ?? false;
}
