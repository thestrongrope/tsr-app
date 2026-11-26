import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/admin/models/enrol_by_token.dart';
import 'package:the_strong_rope/features/admin/providers/enrol_by_token_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/enrol_by_token_repository.dart';
import 'package:the_strong_rope/features/admin/screens/admin_screen.dart';
import 'package:the_strong_rope/features/admin/screens/enrol_by_token_screen.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';

const _notFound = 'No registered member has this token';
const _ambiguous =
    'More than one member has that token number. Please contact an admin.';
const _cannotSave = 'This cannot be saved right now. Nothing was changed.';

const _ayd2 = EnrolClassRef(id: 2, code: 'AYD2', name: 'Name of AYD2');

Map<String, Object?> _memberJson({Object? requested}) => {
  'token': 300,
  'name': 'Ali Member',
  'gender': 1,
  'email': 'ali@example.com',
  'mobile': '+911234567890',
  'city': 'Pune',
  'country': 'India',
  'registeredOn': '2026-09-01',
  'requestedClass': requested,
  'classesNow': [
    {'id': 1, 'code': 'AYD1', 'name': 'Name of AYD1', 'level': 'Ammar'},
  ],
  'classesLeft': [
    {'id': 9, 'code': 'OLD9', 'name': 'Old Class', 'leftOn': '2026-08-01'},
  ],
};

MemberDetails _member({EnrolClassRef? requested}) => MemberDetails.fromJson(
  _memberJson(
    requested: requested == null
        ? null
        : {'id': requested.id, 'code': requested.code, 'name': requested.name},
  ),
);

ClassModel _class(int id, String code, int gender, {String status = 'A'}) =>
    ClassModel(
      id: id,
      code: code,
      name: 'Name of $code',
      level: 3,
      gender: gender,
      status: status,
    );

class _Call {
  _Call(this.path, this.data);
  final String path;
  final Object? data;
}

class _FakeApi implements ApiClient {
  final calls = <_Call>[];
  Object? answer;
  ApiException? failure;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add(_Call(path, queryParameters));
    if (failure != null) throw failure!;
    return answer as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add(_Call(path, data));
    if (failure != null) throw failure!;
    return answer as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

class _FixedClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('parsing', () {
    test(
      'a member keeps every field, both class lists and the asked class',
      () {
        final m = _member(requested: _ayd2);

        expect(m.token, 300);
        expect(m.name, 'Ali Member');
        expect(m.gender, 1);
        expect(m.email, 'ali@example.com');
        expect(m.mobile, '+911234567890');
        expect(m.city, 'Pune');
        expect(m.country, 'India');
        expect(m.registeredOn, '2026-09-01');
        expect(m.requestedClass?.code, 'AYD2');
        expect(m.classesNow.single.id, 1);
        expect(m.classesLeft.single.leftOn, '2026-08-01');
      },
    );

    test('a member with no link class and no contact still parses', () {
      final m = MemberDetails.fromJson({
        'token': 5,
        'name': 'No Contact',
        'gender': null,
        'email': null,
        'mobile': null,
        'city': null,
        'country': null,
        'registeredOn': null,
        'requestedClass': null,
        'classesNow': [],
        'classesLeft': [],
      });

      expect(m.requestedClass, isNull);
      expect(m.gender, isNull);
      expect(m.email, isNull);
    });
  });

  group('repository', () {
    late _FakeApi api;
    late EnrolByTokenRepository repo;

    setUp(() {
      api = _FakeApi();
      repo = EnrolByTokenRepository(apiClient: api);
    });

    test('lookup reads the member from the token path', () async {
      api.answer = _memberJson();

      final m = await repo.lookup(300);

      expect(api.calls.single.path, '/admin/members/300');
      expect(m.name, 'Ali Member');
    });

    test('a 404 is MemberNotFound with the server sentence', () async {
      api.failure = const ApiException(_notFound, 404);

      await expectLater(
        repo.lookup(7),
        throwsA(
          isA<MemberNotFound>().having((e) => e.message, 'message', _notFound),
        ),
      );
    });

    test('a 422 ambiguous_token is its own error', () async {
      api.failure = const ApiException(
        _ambiguous,
        422,
        body: {'detail': _ambiguous, 'code': 'ambiguous_token'},
      );

      await expectLater(repo.lookup(7), throwsA(isA<AmbiguousToken>()));
    });

    test('a 429 keeps its ApiException', () async {
      api.failure = const ApiException('Too many lookups.', 429);

      await expectLater(
        repo.lookup(7),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
      );
    });

    test('enrol posts the class id and ignores the answer', () async {
      api.answer = {'saved': true, 'roster': null};

      await repo.enrol(token: 300, classId: 2);

      expect(api.calls.single.path, '/admin/members/300/enrolments');
      expect(api.calls.single.data, {'classId': 2});
    });

    test('409 already_enrolled and 422 other_gender are typed', () async {
      api.failure = const ApiException(
        'This member is already in this class',
        409,
        body: {'code': 'already_enrolled'},
      );
      await expectLater(
        repo.enrol(token: 300, classId: 2),
        throwsA(isA<AlreadyEnrolled>()),
      );

      api.failure = const ApiException(
        'This class is for the other gender',
        422,
        body: {'code': 'other_gender'},
      );
      await expectLater(
        repo.enrol(token: 300, classId: 2),
        throwsA(isA<OtherGender>()),
      );
    });

    test('an unlabelled 409 stays an ApiException', () async {
      api.failure = const ApiException('Conflict', 409);

      await expectLater(
        repo.enrol(token: 300, classId: 2),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('permission', () {
    testWidgets('the Admin card shows only with members:enrol-by-token', (
      tester,
    ) async {
      Future<void> pumpAdmin(List<String> held) => tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            permissionsProvider.overrideWith((ref) => _FixedPermissions(held)),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const AdminScreen()),
              ],
            ),
          ),
        ),
      );

      await pumpAdmin(['members:enrol-by-token:all']);
      await tester.pumpAndSettle();
      expect(find.text('Enrol by token'), findsOneWidget);

      await pumpAdmin(['reports:read:gender']);
      await tester.pumpAndSettle();
      expect(find.text('Enrol by token'), findsNothing);
    });
  });

  group('screen', () {
    late List<int> lookups;
    late List<({int token, int classId})> enrols;
    Future<MemberDetails> Function(int) lookup = (_) async => _member();
    Future<void> Function(int, int) enrol = (_, _) async {};

    setUp(() {
      lookups = [];
      enrols = [];
      lookup = (_) async => _member();
      enrol = (_, _) async {};
    });

    final classes = [
      _class(1, 'AYD1', 1),
      _class(2, 'AYD2', 1),
      _class(3, 'AYL1', 2),
      _class(4, 'AYD4', 1, status: 'I'),
    ];

    Future<void> pump(WidgetTester tester) async {
      // Tall enough that the whole form is built; the list is lazy.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            lookupMemberProvider.overrideWithValue((token) {
              lookups.add(token);
              return lookup(token);
            }),
            enrolMemberProvider.overrideWithValue(({
              required int token,
              required int classId,
            }) {
              enrols.add((token: token, classId: classId));
              return enrol(token, classId);
            }),
            classesProvider.overrideWith(
              (ref) => _FixedClassesNotifier(ClassesState(classes: classes)),
            ),
          ],
          child: const MaterialApp(home: EnrolByTokenScreen()),
        ),
      );
    }

    Future<void> lookUp(WidgetTester tester, String token) async {
      await tester.enterText(find.byType(TextField).first, token);
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseAndConfirm(WidgetTester tester, String code) async {
      await tester.tap(find.text('Name of $code'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    testWidgets('the token field takes digits only and must not be empty', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a token number'), findsOneWidget);
      expect(lookups, isEmpty);

      await tester.enterText(find.byType(TextField).first, '12ab3');
      await tester.pump();
      expect(find.text('123'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid token number'), findsOneWidget);
      expect(lookups, isEmpty);
    });

    testWidgets('a found member shows every field the lookup returns', (
      tester,
    ) async {
      await pump(tester);
      await lookUp(tester, '300');

      expect(lookups, [300]);
      expect(find.text('Ali Member'), findsOneWidget);
      expect(find.text('300'), findsWidgets);
      expect(find.text('Gents'), findsOneWidget);
      expect(find.text('ali@example.com'), findsOneWidget);
      expect(find.text('+911234567890'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('2026-09-01'), findsOneWidget);
      expect(find.text('OLD9'), findsOneWidget);
      expect(find.textContaining('2026-08-01'), findsOneWidget);
    });

    testWidgets('Asked for shows only when the member came from a link', (
      tester,
    ) async {
      lookup = (_) async => _member(requested: _ayd2);
      await pump(tester);
      await lookUp(tester, '300');
      expect(find.textContaining('Asked for AYD2'), findsOneWidget);

      lookup = (_) async => _member();
      await pump(tester);
      await lookUp(tester, '300');
      expect(find.textContaining('Asked for'), findsNothing);
    });

    testWidgets('not found shows only the sentence', (tester) async {
      lookup = (_) async => throw const MemberNotFound(_notFound);
      await pump(tester);
      await lookUp(tester, '7');

      expect(find.text(_notFound), findsOneWidget);
      expect(find.text('Look up'), findsOneWidget);
      expect(find.text('Choose class'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('an ambiguous token says to contact an admin', (tester) async {
      lookup = (_) async => throw const AmbiguousToken(_ambiguous);
      await pump(tester);
      await lookUp(tester, '7');

      expect(find.text(_ambiguous), findsOneWidget);
      expect(find.text('Choose class'), findsNothing);
    });

    testWidgets('a rate limit shows the server message and can retry', (
      tester,
    ) async {
      lookup = (_) async =>
          throw const ApiException('Too many lookups. Wait a while.', 429);
      await pump(tester);
      await lookUp(tester, '7');

      expect(find.text('Too many lookups. Wait a while.'), findsOneWidget);
      lookup = (_) async => _member();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Member'), findsOneWidget);
    });

    testWidgets('the chooser lists active classes of the member gender', (
      tester,
    ) async {
      await pump(tester);
      await lookUp(tester, '300');

      expect(find.text('Choose class'), findsOneWidget);
      expect(find.text('Name of AYD2'), findsOneWidget);
      expect(find.text('Name of AYL1'), findsNothing);
      expect(find.text('Name of AYD4'), findsNothing);
    });

    testWidgets('a class the member is in is disabled and cannot be chosen', (
      tester,
    ) async {
      await pump(tester);
      await lookUp(tester, '300');

      expect(find.text('Already in this class'), findsOneWidget);
      await tester.ensureVisible(find.text('Already in this class'));
      await tester.tap(find.text('Already in this class'));
      await tester.pumpAndSettle();
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm'),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('the class the member asked for is listed first', (
      tester,
    ) async {
      lookup = (_) async => _member(requested: _ayd2);
      await pump(tester);
      await lookUp(tester, '300');

      final chooser = find.byKey(const ValueKey('class-chooser'));
      final titles = tester
          .widgetList<Text>(
            find.descendant(
              of: chooser,
              matching: find.textContaining('Name of'),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(titles.first, 'Name of AYD2');
    });

    testWidgets('confirm asks with the name and class, then enrols once', (
      tester,
    ) async {
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');

      expect(find.text('Enrol Ali Member (300) in AYD2?'), findsOneWidget);
      expect(enrols, isEmpty);

      await tester.tap(find.text('Enrol'));
      await tester.pumpAndSettle();

      expect(enrols, [(token: 300, classId: 2)]);
      expect(find.text('Ali Member added to AYD2'), findsOneWidget);
      expect(find.text('Choose class'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
    });

    testWidgets('cancelling the confirmation enrols nobody', (tester) async {
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(enrols, isEmpty);
      expect(find.text('Ali Member'), findsOneWidget);
    });

    testWidgets('a saved answer with no roster is a success', (tester) async {
      final api = _FakeApi()..answer = {'saved': true, 'roster': null};
      enrol = (token, classId) => EnrolByTokenRepository(
        apiClient: api,
      ).enrol(token: token, classId: classId);
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');
      await tester.tap(find.text('Enrol'));
      await tester.pumpAndSettle();

      expect(find.text('Ali Member added to AYD2'), findsOneWidget);
    });

    testWidgets('a double tap on Enrol sends one request', (tester) async {
      final gate = Completer<void>();
      enrol = (_, _) => gate.future;
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');

      await tester.tap(find.text('Enrol'));
      await tester.tap(find.text('Enrol'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(enrols, hasLength(1));
      expect(find.text('Ali Member added to AYD2'), findsOneWidget);
    });

    testWidgets('a double tap on Confirm opens one dialog', (tester) async {
      await pump(tester);
      await lookUp(tester, '300');
      await tester.tap(find.text('Name of AYD2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm'));

      await tester.tap(find.text('Confirm'));
      await tester.tap(find.text('Confirm'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    Future<void> failWith(WidgetTester tester, Object error) async {
      enrol = (_, _) async => throw error;
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');
      await tester.tap(find.text('Enrol'));
      await tester.pumpAndSettle();
    }

    testWidgets('already enrolled shows the server message', (tester) async {
      await failWith(
        tester,
        const AlreadyEnrolled('Ali Member is already in AYD2'),
      );

      expect(find.text('Ali Member is already in AYD2'), findsOneWidget);
      expect(find.text('Ali Member'), findsOneWidget);
    });

    testWidgets('the other gender shows the server message', (tester) async {
      await failWith(tester, const OtherGender('This class is for ladies'));

      expect(find.text('This class is for ladies'), findsOneWidget);
    });

    testWidgets('a rate limit on enrol shows the server message', (
      tester,
    ) async {
      await failWith(tester, const ApiException('Slow down a little.', 429));

      expect(find.text('Slow down a little.'), findsOneWidget);
    });

    testWidgets('a server fault says nothing was changed', (tester) async {
      await failWith(tester, const ApiException('<html>boom</html>', 500));

      expect(find.text(_cannotSave), findsOneWidget);
      expect(find.text('Ali Member'), findsOneWidget);
    });

    testWidgets('no network says nothing was changed', (tester) async {
      await failWith(tester, const ApiException('offline', 0));

      expect(find.text(_cannotSave), findsOneWidget);
    });

    testWidgets('closing the screen mid-request does not throw', (
      tester,
    ) async {
      final gate = Completer<void>();
      enrol = (_, _) => gate.future;
      await pump(tester);
      await lookUp(tester, '300');
      await chooseAndConfirm(tester, 'AYD2');
      await tester.tap(find.text('Enrol'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
