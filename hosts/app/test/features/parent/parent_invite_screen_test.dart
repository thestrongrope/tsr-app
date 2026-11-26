import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/parent/models/models.dart';
import 'package:the_strong_rope/features/parent/providers/parent_provider.dart';
import 'package:the_strong_rope/features/parent/repositories/parent_repository.dart';
import 'package:the_strong_rope/features/parent/screens/parent_invite_screen.dart';

class _FakeRepository extends ParentRepository {
  ParentInvitePreview preview = const ParentInvitePreview(
    state: 'valid',
    firstName: 'Zaid',
  );
  Object? inspectError;
  Object? acceptError;
  int inspectCalls = 0;
  final List<String> accepted = [];

  @override
  Future<ParentInvitePreview> inspectInvite(String code) async {
    inspectCalls++;
    final error = inspectError;
    if (error != null && inspectCalls == 1) throw error;
    return preview;
  }

  @override
  Future<void> acceptInvite(String code, String relationship) async {
    final error = acceptError;
    if (error != null) throw error;
    accepted.add('$code:$relationship');
  }

  @override
  Future<List<ChildModel>> getChildren() async => const [];
}

/// A parent opens an invite link in the app (#1122): sees whose parent they are
/// asked to become, accepts, and is told plainly when the invite cannot be used.
void main() {
  late _FakeRepository repo;

  Future<void> pumpInvite(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/link/AbCd123456',
      routes: [
        GoRoute(
          path: AppRoutes.parentInviteLink,
          builder: (_, state) =>
              ParentInviteScreen(code: state.pathParameters['code']!),
        ),
        GoRoute(
          path: AppRoutes.myChildren,
          builder: (_, _) => const Text('My children page'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [parentRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repo = _FakeRepository());

  Future<void> choose(WidgetTester tester, String relationship) async {
    await tester.tap(find.text(relationship));
    await tester.pumpAndSettle();
  }

  testWidgets('a valid invite names the child and asks to accept', (
    tester,
  ) async {
    await pumpInvite(tester);

    expect(find.textContaining('Zaid'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('accepting sends the relationship and shows My children', (
    tester,
  ) async {
    await pumpInvite(tester);

    await choose(tester, 'Mother');
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.accepted, ['AbCd123456:mother']);
    expect(find.text('My children page'), findsOneWidget);
  });

  testWidgets('Accept waits until a relationship is chosen', (tester) async {
    await pumpInvite(tester);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.accepted, isEmpty);
    expect(find.text('My children page'), findsNothing);
  });

  testWidgets('an expired, used or cancelled invite is refused', (
    tester,
  ) async {
    repo.preview = const ParentInvitePreview(state: 'expired');
    await pumpInvite(tester);

    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('an unknown invite says it was not found', (tester) async {
    repo.preview = const ParentInvitePreview(state: 'not_found');
    await pumpInvite(tester);

    expect(find.textContaining('could not find'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('an invite used since it was opened is refused on accept', (
    tester,
  ) async {
    repo.acceptError = ApiException('gone', 410);
    await pumpInvite(tester);

    await choose(tester, 'Father');
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('My children page'), findsNothing);
  });

  testWidgets('the child cannot accept their own invite', (tester) async {
    repo.acceptError = ApiException('self', 422);
    await pumpInvite(tester);

    await choose(tester, 'Father');
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot accept'), findsOneWidget);
    expect(find.text('My children page'), findsNothing);
  });

  testWidgets('already linked says so and offers My children', (tester) async {
    repo.acceptError = ApiException('linked', 409);
    await pumpInvite(tester);

    await choose(tester, 'Guardian');
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already linked'), findsOneWidget);
    await tester.tap(find.text('See my children'));
    await tester.pumpAndSettle();
    expect(find.text('My children page'), findsOneWidget);
  });

  testWidgets('offline: says so and Retry loads the invite again', (
    tester,
  ) async {
    repo.inspectError = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    await pumpInvite(tester);

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    expect(find.text('Accept'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.inspectCalls, 2);
    expect(find.textContaining('Zaid'), findsOneWidget);
  });
}
