import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/account_deletion/screens/account_deleted_screen.dart';
import 'package:the_strong_rope/features/account_deletion/screens/delete_account_screen.dart';

Widget _wrap(Widget screen) {
  return ProviderScope(child: MaterialApp(home: screen));
}

void main() {
  testWidgets('the delete account screen states the window and the terms', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const DeleteAccountScreen()));

    // Apple requires the member to be told how long a non-immediate deletion
    // takes, before they commit to it.
    expect(find.textContaining('60 days'), findsOneWidget);
    expect(find.text('Request account deletion'), findsOneWidget);
    expect(find.text('Keep my account'), findsOneWidget);
  });

  testWidgets('the delete account screen offers an optional reason', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const DeleteAccountScreen()));

    expect(find.text('Reason (optional)'), findsOneWidget);
  });

  testWidgets('the deleted screen explains that signing in starts afresh', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AccountDeletedScreen()));

    expect(find.text('Your account has been deleted'), findsOneWidget);
    expect(find.textContaining('create a new account'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('the deleted screen says when some data could not be removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AccountDeletedScreen(someDataRemains: true)),
    );
    expect(find.textContaining('could not be removed'), findsOneWidget);

    await tester.pumpWidget(_wrap(const AccountDeletedScreen()));
    expect(find.textContaining('could not be removed'), findsNothing);
  });
}
