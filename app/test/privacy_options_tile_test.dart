import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/services/ad_service.dart';
import 'package:shardfall/services/save_service.dart';
import 'package:shardfall/widgets/privacy_options_tile.dart';

class _NoopAdPlatform implements AdPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<AdBannerHandle?> loadBanner(String adUnitId) async => null;

  @override
  Future<AdInterstitialHandle?> loadInterstitial(String adUnitId) async => null;
}

class _ConsentPlatform implements AdConsentPlatform {
  _ConsentPlatform(this.required);

  final bool required;
  int showCalls = 0;

  @override
  Future<bool> gatherConsent() async => true;

  @override
  Future<bool> get isPrivacyOptionsRequired async => required;

  @override
  Future<void> showPrivacyOptions() async => showCalls++;
}

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues(const {'gold': 0});
  });

  Future<AdService> buildService(_ConsentPlatform consent) async {
    final save = await SaveService.load(emptyLibrary);
    final service = AdService(
      save: save,
      platform: _NoopAdPlatform(),
      consentPlatform: consent,
    );
    await service.initialize();
    return service;
  }

  testWidgets('shows the privacy entry point only when Google requires it', (
    tester,
  ) async {
    final hiddenService = await buildService(_ConsentPlatform(false));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PrivacyOptionsTile(ads: hiddenService)),
      ),
    );
    expect(find.text('Privacy choices'), findsNothing);

    final requiredConsent = _ConsentPlatform(true);
    final visibleService = await buildService(requiredConsent);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PrivacyOptionsTile(ads: visibleService)),
      ),
    );

    expect(find.text('Privacy choices'), findsOneWidget);
    await tester.tap(find.text('Privacy choices'));
    await tester.pump();
    expect(requiredConsent.showCalls, 1);
  });
}
