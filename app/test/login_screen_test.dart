import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shardfall/auth/login_screen.dart';
import 'package:shardfall/services/auth_service.dart';
import 'package:shardfall/services/save_service.dart';

void main() {
  const emptyLibrary = CardLibrary(byId: {}, starterDecks: {});

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('the guest and account choices are remembered, not asked again',
      () async {
    // The login screen appears once. Whatever the player picks there has to
    // survive a restart, or it becomes a nag screen.
    final save = await SaveService.load(emptyLibrary);
    expect(save.guestMode, isFalse);
    expect(save.accountLinked, isFalse);

    await save.setGuestMode(true);
    await save.setAccountLinked(true);

    final reloaded = await SaveService.load(emptyLibrary);
    expect(reloaded.guestMode, isTrue);
    expect(reloaded.accountLinked, isTrue);
  });

  testWidgets('the login screen offers Google and guest, and guest pops false',
      (tester) async {
    final save = await SaveService.load(emptyLibrary);
    final auth = AuthService();
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                  builder: (_) => LoginScreen(auth: auth, save: save)),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN WITH GOOGLE'), findsOneWidget);
    expect(find.text('PLAY AS GUEST'), findsOneWidget);

    await tester.tap(find.text('PLAY AS GUEST'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(save.guestMode, isTrue,
        reason: 'choosing guest once must silence the screen for good');
    auth.dispose();
  });
}
