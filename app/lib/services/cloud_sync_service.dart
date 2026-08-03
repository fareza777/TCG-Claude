import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'backend_config.dart';
import 'purchase_catalog.dart';
import 'save_service.dart';

/// Raised by the save-version guard trigger when a stale device tries to push.
const _staleSaveCode = '55000';

/// Cloud save and paid-entitlement recovery.
///
/// Two very different guarantees live here, and the difference matters:
///
///   * [restoreEntitlements] is **additive and conflict-free**. Purchases are
///     server-verified rows keyed by Google's purchase token, so replaying them
///     onto any device can only ever grant Gold that was genuinely paid for.
///     This is what makes a reinstall whole again.
///   * [pushSave] / [pullSave] move the whole profile, which two devices can
///     genuinely disagree about. This class refuses to guess: it never
///     overwrites local progress, it reports the conflict instead.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService({
    required this.save,
    required this.auth,
    this.client,
  });

  final SaveService save;
  final AuthService auth;

  /// Injected by tests; production falls back to the shared Supabase instance.
  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Set when the cloud holds a save but this device has its own progress.
  /// Nothing is overwritten; the player has to choose.
  bool cloudSaveConflict = false;

  /// Gold recovered from server-verified purchases during the last sync.
  int recoveredGold = 0;

  String? lastError;

  int _serverVersion = 0;

  bool get _enabled => BackendConfig.hasBackend && auth.isSignedIn;

  /// Runs the full sync for a freshly signed-in player.
  ///
  /// Money first: anything paid for is pushed up and pulled back before the
  /// profile sync, so even if that later step fails the player has their Gold.
  Future<void> syncOnSignIn() async {
    if (!_enabled) return;
    lastError = null;
    await retryUnverifiedPurchases();
    await restoreEntitlements();
    await _adoptCloudSaveIfSafe();
  }

  /// Re-sends purchases delivered while the backend was unreachable.
  Future<void> retryUnverifiedPurchases() async {
    if (!_enabled || save.unverifiedPurchases.isEmpty) return;

    for (final entry in save.unverifiedPurchases.toList()) {
      final separator = entry.indexOf('|');
      if (separator <= 0) continue;

      final productId = entry.substring(0, separator);
      final token = entry.substring(separator + 1);
      if (await verifyPurchase(productId: productId, purchaseToken: token)) {
        await save.markPurchaseVerified(productId, token);
      }
    }
  }

  /// Reconciles this device against every purchase the backend knows about.
  ///
  /// Granted rows are re-delivered; rows Google has voided have their Gold
  /// taken back. Idempotent twice over: the local ledger in [SaveService] skips
  /// anything already settled, and the rows themselves are unique per Google
  /// purchase token.
  Future<int> restoreEntitlements() async {
    if (!_enabled) return 0;

    try {
      final rows = await _supabase
          .from('purchases')
          .select('product_id, purchase_token, order_id, state');

      var granted = 0;
      for (final row in rows) {
        final token = (row['purchase_token'] as String?)?.trim() ?? '';
        if (token.isEmpty) continue;

        final productId = row['product_id'] as String;
        final orderId = (row['order_id'] as String?)?.trim() ?? '';
        final aliases = {if (orderId.isNotEmpty) orderId};

        if (row['state'] == 'refunded') {
          await save.revokePurchasedGold(
            productId: productId,
            purchaseId: token,
            aliasIds: aliases,
          );
          continue;
        }

        final delivered = await save.grantPurchasedGold(
          productId: productId,
          purchaseId: token,
          aliasIds: aliases,
        );
        if (delivered) granted++;
      }

      recoveredGold = granted * PurchaseCatalog.gold500Amount;
      if (granted > 0) notifyListeners();
      return granted;
    } catch (error) {
      lastError = 'Could not restore purchases: $error';
      debugPrint(lastError);
      return 0;
    }
  }

  /// Asks the backend to verify a receipt straight from Google and record it.
  ///
  /// Returns false when the purchase could not be recorded. The caller has
  /// already granted the Gold locally, so a false here means "not durable yet",
  /// never "take the Gold back".
  Future<bool> verifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    if (!_enabled) return false;

    try {
      final response = await _supabase.functions.invoke(
        'verify-purchase',
        body: {'productId': productId, 'purchaseToken': purchaseToken},
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['granted'] == true || data?['alreadyRecorded'] == true;
    } catch (error) {
      lastError = 'Purchase verification failed: $error';
      debugPrint(lastError);
      return false;
    }
  }

  /// Loads the stored snapshot, or null when this account has never pushed.
  Future<Map<String, dynamic>?> pullSave() async {
    if (!_enabled) return null;

    try {
      final row = await _supabase
          .from('profiles')
          .select('save_data, save_version')
          .eq('user_id', auth.user!.id)
          .maybeSingle();
      if (row == null) return null;

      _serverVersion = (row['save_version'] as num?)?.toInt() ?? 0;
      final data = row['save_data'] as Map<String, dynamic>?;
      return (data == null || data.isEmpty) ? null : data;
    } catch (error) {
      lastError = 'Could not read the cloud save: $error';
      debugPrint(lastError);
      return null;
    }
  }

  /// Uploads the current profile. Retries once against the stored version if
  /// another device pushed in between.
  Future<bool> pushSave() async {
    if (!_enabled) return false;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _supabase.from('profiles').upsert({
          'user_id': auth.user!.id,
          'save_data': save.toSnapshot(),
          'save_version': _serverVersion + 1,
        });
        _serverVersion++;
        return true;
      } on PostgrestException catch (error) {
        if (error.code != _staleSaveCode || attempt == 1) {
          lastError = 'Could not upload the save: ${error.message}';
          debugPrint(lastError);
          return false;
        }
        await pullSave(); // refreshes _serverVersion, then retry once
      } catch (error) {
        lastError = 'Could not upload the save: $error';
        debugPrint(lastError);
        return false;
      }
    }
    return false;
  }

  /// Adopts the cloud save only on a device with nothing to lose.
  ///
  /// Anything else is a real conflict between two played-on devices, and
  /// picking a winner automatically is how people lose collections.
  Future<void> _adoptCloudSaveIfSafe() async {
    final snapshot = await pullSave();

    if (snapshot == null) {
      await pushSave(); // first device for this account seeds the cloud
      return;
    }

    if (save.hasLocalProgress) {
      cloudSaveConflict = true;
      notifyListeners();
      return;
    }

    await save.applySnapshot(snapshot);
    notifyListeners();
  }

  /// Explicit player choice: take the cloud save and drop local progress.
  Future<bool> resolveWithCloudSave() async {
    final snapshot = await pullSave();
    if (snapshot == null) return false;
    await save.applySnapshot(snapshot);
    cloudSaveConflict = false;
    notifyListeners();
    return true;
  }

  /// Explicit player choice: keep this device and overwrite the cloud.
  Future<bool> resolveWithLocalSave() async {
    final pushed = await pushSave();
    if (pushed) {
      cloudSaveConflict = false;
      notifyListeners();
    }
    return pushed;
  }
}
