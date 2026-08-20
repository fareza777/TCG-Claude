import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shardfall/widgets/delete_account_tile.dart';

void main() {
  testWidgets('requires explicit confirmation before deleting the account', (
    tester,
  ) async {
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeleteAccountTile(
            onDelete: () async {
              deleteCalls++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text('Delete Shardfall account?'), findsOneWidget);

    await tester.tap(find.text('DELETE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(find.text('Account deleted'), findsOneWidget);
  });

  testWidgets('keeps the dialog open and reports a deletion failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeleteAccountTile(onDelete: () async => false)),
      ),
    );

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not delete the account. Try again.'),
      findsOneWidget,
    );
  });
}
