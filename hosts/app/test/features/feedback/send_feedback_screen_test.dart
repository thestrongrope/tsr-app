import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/core/widgets/sign_in_invite.dart';
import 'package:the_strong_rope/features/auth/models/auth_state.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/feedback/providers/feedback_queue_provider.dart';
import 'package:the_strong_rope/features/feedback/screens/send_feedback_screen.dart';
import 'package:the_strong_rope/features/feedback/services/feedback_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';

import 'feedback_queue_test.dart' show ScriptedFeedbackRepository;

class _MemoryStore extends FeedbackQueueStore {
  final _items = <int, List<QueuedFeedback>>{};

  @override
  List<QueuedFeedback> read(int token) => _items[token] ?? const [];

  @override
  Future<void> write(int token, List<QueuedFeedback> items) async {
    _items[token] = items;
  }
}

class _Offline extends OfflineNotifier {
  _Offline(this._offline);

  final bool _offline;

  @override
  bool build() => _offline;
}

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _MemoryStore box;
  late ScriptedFeedbackRepository repo;

  // Hive's file I/O never completes inside a widget test's fake clock.
  setUp(() {
    box = _MemoryStore();
    repo = ScriptedFeedbackRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool offline = false,
    AuthStatus status = AuthStatus.authenticated,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentActionsMemberProvider.overrideWithValue(100),
          feedbackQueueStoreProvider.overrideWithValue(box),
          feedbackRepositoryProvider.overrideWithValue(repo),
          isOfflineProvider.overrideWith(() => _Offline(offline)),
          authStateProvider.overrideWith(
            (ref) => _FixedAuth(AuthState(status: status)),
          ),
        ],
        child: const MaterialApp(
          home: SignedInOnly(
            title: 'Send feedback',
            message: 'Sign in to send us feedback.',
            child: SendFeedbackScreen(),
          ),
        ),
      ),
    );
  }

  Future<void> sendHello(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
  }

  testWidgets('Me shows the Send feedback tile', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          unreadNotificationCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(home: MeScreen()),
      ),
    );

    expect(find.text('Send feedback'), findsOneWidget);
  });

  testWidgets('an online send confirms it was received', (tester) async {
    await pump(tester);

    await sendHello(tester);

    expect(find.text('Received. Thank you.'), findsOneWidget);
    expect(repo.sentIds, hasLength(1));
  });

  testWidgets('an online failure says so and keeps the text', (tester) async {
    repo.answers['Hello'] = const ApiException('offline', 0);
    await pump(tester);

    await sendHello(tester);

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Received. Thank you.'), findsNothing);
  });

  testWidgets('an offline send is kept and says it will be sent later', (
    tester,
  ) async {
    await pump(tester, offline: true);

    await sendHello(tester);

    expect(
      find.text('Saved. It will be sent when you are back online.'),
      findsOneWidget,
    );
    expect(repo.sentIds, isEmpty);
    expect(box.read(100).single.text, 'Hello');
    expect(find.text('Waiting to be sent'), findsOneWidget);
  });

  testWidgets('a guest is asked to sign in instead of seeing the form', (
    tester,
  ) async {
    await pump(tester, status: AuthStatus.unauthenticated);

    expect(find.text('Sign in to send us feedback.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
