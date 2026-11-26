import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<bool> Function(Uri) launch, {
  User? user,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp(home: MeScreen(launch: launch)),
    ),
  );
}

User _member({required int token}) => User(
  id: 1,
  token: token,
  email: 'a@example.com',
  name: 'Member',
  roleId: 0,
);

void main() {
  testWidgets('a member sees their token number under their name (#1147)', (
    tester,
  ) async {
    await _pump(tester, (_) async => true, user: _member(token: 4321));

    expect(find.text('Token 4321'), findsOneWidget);
  });

  testWidgets('tapping the token number copies it and says so', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester, (_) async => true, user: _member(token: 4321));

    await tester.tap(find.text('Token 4321'));
    await tester.pump();

    expect(copied, '4321');
    expect(find.text('Token number copied'), findsOneWidget);
  });

  testWidgets('a failed copy says so', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester, (_) async => true, user: _member(token: 4321));

    await tester.tap(find.text('Token 4321'));
    await tester.pump();

    expect(find.text("Couldn't copy the token number."), findsOneWidget);
  });

  testWidgets('a member with no token number yet sees no token line', (
    tester,
  ) async {
    await _pump(tester, (_) async => true, user: _member(token: 0));

    expect(find.text('Member'), findsOneWidget);
    expect(find.textContaining('Token'), findsNothing);
  });

  testWidgets('Donate opens the public donate page', (tester) async {
    final opened = <Uri>[];
    await _pump(tester, (uri) async {
      opened.add(uri);
      return true;
    });

    await tester.tap(find.text('Donate'));
    await tester.pump();

    expect(opened, [Uri.parse('https://thestrongrope.com/donate')]);
  });

  testWidgets('Donate says so when the page cannot be opened', (tester) async {
    await _pump(tester, (_) async => false);

    await tester.tap(find.text('Donate'));
    await tester.pump();

    expect(find.text("Couldn't open the donation page."), findsOneWidget);
  });
}
