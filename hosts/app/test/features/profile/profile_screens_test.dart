import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/profile/presentation/edit_profile_screen.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';
import 'package:the_strong_rope/features/profile/presentation/profile_screen.dart';

const _member = User(
  id: 1,
  token: 7,
  email: 'a@example.com',
  name: 'Test Member',
  roleId: 1,
  mobile: '+911234567890',
);

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<void> updateUserLocally(User updatedUser) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi implements ApiClient {
  _FakeApi({this.fail = false});

  final bool fail;
  Map<String, dynamic>? sent;

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    sent = data;
    if (fail) throw ApiException('Server said no', 500);
    return {
      'id': 1,
      'token': 7,
      'email': 'a@example.com',
      'name': data['name'],
      'roleid': 1,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _signedIn = AuthState(status: AuthStatus.authenticated, user: _member);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AuthState auth = _signedIn,
  ApiClient? api,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.push('/screen'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/screen', builder: (_, _) => screen),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => _FixedAuth(auth)),
        unreadNotificationCountProvider.overrideWithValue(0),
        if (api != null) apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // A skeleton pulses forever, so it cannot settle.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  group('Profile', () {
    testWidgets('shows a skeleton while the profile loads', (tester) async {
      await _pump(
        tester,
        const ProfileScreen(),
        auth: const AuthState(status: AuthStatus.loading),
        settle: false,
      );
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('says it failed to load and offers Retry', (tester) async {
      await _pump(
        tester,
        const ProfileScreen(),
        auth: const AuthState(status: AuthStatus.error, error: 'boom'),
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('Sign Out is a standard outlined button; only Delete is red', (
      tester,
    ) async {
      await _pump(tester, const ProfileScreen());
      await tester.scrollUntilVisible(
        find.text('Delete my account'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final signOut = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Sign Out'),
      );
      expect(signOut.style, isNull);
      expect(find.text('Delete my account'), findsOneWidget);
      final delete = tester.widget<Text>(find.text('Delete my account'));
      expect(delete.style?.color, AppTheme.errorRed);
    });
  });

  group('Edit profile', () {
    testWidgets('shows a skeleton while the profile loads', (tester) async {
      await _pump(
        tester,
        const EditProfileScreen(),
        auth: const AuthState(status: AuthStatus.loading),
        settle: false,
      );
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('says it failed to load and offers Retry', (tester) async {
      await _pump(
        tester,
        const EditProfileScreen(),
        auth: const AuthState(status: AuthStatus.error, error: 'boom'),
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('confirms a saved change', (tester) async {
      final api = _FakeApi();
      await _pump(tester, const EditProfileScreen(), api: api);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Test Member'),
        'New Name',
      );
      await tester.scrollUntilVisible(
        find.text('Update Profile'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Update Profile'));
      await tester.pumpAndSettle();

      expect(api.sent?['name'], 'New Name');
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets('says a change was not saved and keeps what was entered', (
      tester,
    ) async {
      await _pump(tester, const EditProfileScreen(), api: _FakeApi(fail: true));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Test Member'),
        'New Name',
      );
      await tester.scrollUntilVisible(
        find.text('Update Profile'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Update Profile'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your changes were not saved'),
        findsOneWidget,
      );
      expect(find.text('New Name'), findsOneWidget);
    });
  });

  testWidgets('Me shows the member and its entries', (tester) async {
    await _pump(tester, const MeScreen());
    expect(find.text('Test Member'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Donate'), findsOneWidget);
  });
}
