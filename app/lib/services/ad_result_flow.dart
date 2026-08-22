import 'ad_service.dart';

/// Called when a battle has ended and the player is back on a safe,
/// non-gameplay screen.
///
/// This is the one seam every result path already goes through — story,
/// duel and arena all call it — so counting the battle here means a new
/// result screen cannot accidentally skip the new-player grace period.
///
/// The count is recorded *after* the eligibility check, so the first
/// [AdPolicy.graceBattles] fights finish without a single interruption and
/// the one after them is the first to carry an ad.
///
/// Missing services and unavailable ads stay a normal no-op.
Future<bool> showPostResultInterstitial(AdService? adService) async {
  if (adService == null) return false;
  final shown = await adService.showInterstitialIfEligible();
  await adService.save.recordBattlePlayed();
  return shown;
}
