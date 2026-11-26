import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/admin/models/class_access.dart';
import 'package:the_strong_rope/features/admin/models/permission_grants.dart';
import 'package:the_strong_rope/features/admin/providers/class_access_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/class_access_repository.dart';
import 'package:the_strong_rope/features/admin/screens/admin_screen.dart';
import 'package:the_strong_rope/features/admin/screens/class_access_screen.dart';

const _bilal2 = AccessClass(id: 12, code: 'B-2', name: 'Bilal 2');
const _ammar1 = AccessClass(id: 20, code: 'A-1', name: 'Ammar 1');

const _staleMessage =
    'This member was just changed by someone else. '
    'Open them again to see the current access.';

MemberAccess _view({List<AccessRule>? rules, String? fromRole}) => MemberAccess(
  member: const MemberRef(token: 300, name: 'Ali Member'),
  version: '0:3',
  fromRole: fromRole,
  rules:
      rules ??
      const [
        AccessRule(
          id: 3,
          note: 'Gents, levels Bilal',
          createdAt: '2026-10-01T10:00:00',
          classCount: 1,
          classes: [_bilal2],
        ),
      ],
);

const _options = AccessOptions(
  genders: [AccessOption(id: 1, name: 'Gents')],
  levels: [
    AccessOption(id: 5, name: 'Bilal'),
    AccessOption(id: 6, name: 'Ammar'),
  ],
  cities: ['Dubai', 'Pune'],
  countries: ['India', 'UAE'],
  tags: ['Mumbra'],
);

List<Map<String, Object?>> _wire(List<AccessFilter> filters) => [
  for (final f in filters) {'field': f.field, 'values': f.values},
];

const _levelFilter = [
  {
    'field': 'level',
    'values': [5],
  },
];

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

void main() {
  group('parsing', () {
    test(
      'options carry the cities, countries and tags, and none when absent',
      () {
        final withAll = AccessOptions.fromJson({
          'genders': [],
          'levels': [],
          'cities': ['Dubai', 'Pune'],
          'countries': ['India', ''],
          'tags': ['Mumbra'],
        });
        expect(withAll.cities, ['Dubai', 'Pune']);
        expect(withAll.countries, ['India']);
        expect(withAll.tags, ['Mumbra']);
        final none = AccessOptions.fromJson({'genders': [], 'levels': []});
        expect(none.cities, isEmpty);
        expect(none.countries, isEmpty);
        expect(none.tags, isEmpty);
      },
    );

    test('a member view keeps each rule with its classes', () {
      final view = MemberAccess.fromJson({
        'member': {'token': 300, 'name': 'Ali Member', 'gender': 1},
        'version': '0:3',
        'fromRole': null,
        'rules': [
          {
            'id': 3,
            'gender': 1,
            'note': 'Gents, levels Bilal',
            'createdAt': '2026-10-01T10:00:00',
            'conditions': [
              {'field': 'level', 'negate': false, 'value': 5},
            ],
            'classCount': 250,
            'classes': [
              {'id': 12, 'code': 'B-2', 'name': 'Bilal 2', 'ruleId': 3},
            ],
          },
        ],
      });

      expect(view.member.name, 'Ali Member');
      expect(view.fromRole, isNull);
      expect(view.rules.single.classCount, 250);
      expect(view.rules.single.classes.single.name, 'Bilal 2');
    });
  });

  group('repository', () {
    late _FakeApi api;
    late ClassAccessRepository repo;

    setUp(() {
      api = _FakeApi();
      repo = ClassAccessRepository(apiClient: api);
    });

    test('a save answering saved with no member is a success', () async {
      api.answer = {
        'saved': true,
        'member': null,
        'version': null,
        'fromRole': null,
        'rules': [],
      };

      await repo.grant(
        token: 300,
        gender: 1,
        filters: [
          AccessFilter('level', [5]),
          AccessFilter('city', ['Pune', 'Dubai']),
          AccessFilter('country', ['India']),
          AccessFilter('tag', ['Mumbra']),
        ],
        reason: 'Covers Bilal',
        version: '0:3',
        previewHash: 'h1',
      );

      expect(api.calls.single.path, '/admin/class-access/members/300/rules');
      expect(api.calls.single.data, {
        'gender': 1,
        'conditions': [
          {'field': 'level', 'negate': false, 'value': 5},
          {'field': 'city', 'negate': false, 'value': 'Pune'},
          {'field': 'city', 'negate': false, 'value': 'Dubai'},
          {'field': 'country', 'negate': false, 'value': 'India'},
          {'field': 'tag', 'negate': false, 'value': 'Mumbra'},
        ],
        'reason': 'Covers Bilal',
        'version': '0:3',
        'previewHash': 'h1',
      });
    });

    test('preview_changed carries the new classes', () async {
      api.failure = const ApiException(
        'The classes changed since the preview',
        409,
        body: {
          'detail': 'The classes changed since the preview',
          'code': 'preview_changed',
          'classes': [
            {'id': 20, 'code': 'A-1', 'name': 'Ammar 1'},
          ],
          'classCount': 1,
          'previewHash': 'h2',
        },
      );

      await expectLater(
        repo.grant(
          token: 300,
          gender: 1,
          filters: [
            AccessFilter('level', [5]),
          ],
          reason: 'x',
          version: '0:3',
          previewHash: 'h1',
        ),
        throwsA(
          isA<PreviewChanged>()
              .having((e) => e.preview.classes.single.id, 'first class', 20)
              .having((e) => e.preview.previewHash, 'hash', 'h2'),
        ),
      );
    });

    test('member_changed is its own error', () async {
      api.failure = const ApiException(
        'stale',
        409,
        body: {'detail': 'stale', 'code': 'member_changed'},
      );

      await expectLater(
        repo.revoke(id: 3, reason: 'x', version: 'old'),
        throwsA(isA<MemberChanged>()),
      );
      expect(api.calls.single.path, '/admin/class-access/rules/3/revoke');
    });

    test('any other refusal keeps the server words', () async {
      api.failure = const ApiException(
        'This member already has this access',
        409,
      );

      await expectLater(
        repo.revoke(id: 3, reason: 'x', version: 'v'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('search screen', () {
    Future<void> pumpSearch(
      WidgetTester tester,
      Future<List<MemberRef>> Function(String) search,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [classAccessSearchProvider.overrideWithValue(search)],
          child: const MaterialApp(home: ClassAccessScreen()),
        ),
      );
    }

    testWidgets('searches from two characters and lists the members', (
      tester,
    ) async {
      final asked = <String>[];
      await pumpSearch(tester, (q) async {
        asked.add(q);
        return const [MemberRef(token: 300, name: 'Ali Member')];
      });

      await tester.enterText(find.byType(TextField), 'a');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(asked, isEmpty);

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(asked, ['ali']);
      expect(find.text('Ali Member'), findsOneWidget);
      expect(find.text('Token 300'), findsOneWidget);
    });

    testWidgets('no member found says what to try next', (tester) async {
      await pumpSearch(tester, (q) async => const []);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.textContaining('No member found'), findsOneWidget);
      expect(find.textContaining('name or token'), findsWidgets);
    });

    testWidgets('a slower, older reply does not replace the newer one', (
      tester,
    ) async {
      final slow = Completer<List<MemberRef>>();
      await pumpSearch(tester, (q) {
        if (q == 'al') return slow.future;
        return Future.value(const [MemberRef(token: 2, name: 'Newer Result')]);
      });

      await tester.enterText(find.byType(TextField), 'al');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'ali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      slow.complete(const [MemberRef(token: 1, name: 'Older Result')]);
      await tester.pumpAndSettle();

      expect(find.text('Newer Result'), findsOneWidget);
      expect(find.text('Older Result'), findsNothing);
    });

    testWidgets('a failed search says so and can be tried again', (
      tester,
    ) async {
      await pumpSearch(tester, (q) async => throw const ApiException('x', 0));

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('member screen', () {
    late List<Map<String, Object?>> grants;
    late List<Map<String, Object?>> revokes;
    late List<Map<String, Object?>> previews;
    Object? grantFails;
    Object? revokeFails;
    Completer<void>? grantGate;
    Completer<void>? revokeGate;
    late ClassPreview previewAnswer;
    late MemberAccess Function() viewNow;
    var views = 0;

    setUp(() {
      grants = [];
      revokes = [];
      previews = [];
      grantFails = null;
      revokeFails = null;
      grantGate = null;
      revokeGate = null;
      previewAnswer = const ClassPreview(
        classes: [_ammar1],
        count: 1,
        previewHash: 'h1',
      );
      viewNow = _view;
      views = 0;
    });

    Widget wrap({bool pushed = false}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        memberAccessProvider.overrideWith((ref, token) async {
          views++;
          return viewNow();
        }),
        accessOptionsProvider.overrideWith((ref) async => _options),
        previewAccessProvider.overrideWithValue(({
          required int gender,
          required List<AccessFilter> filters,
        }) async {
          previews.add({'gender': gender, 'filters': _wire(filters)});
          return previewAnswer;
        }),
        grantAccessProvider.overrideWithValue(({
          required int token,
          required int gender,
          required List<AccessFilter> filters,
          required String reason,
          required String version,
          required String previewHash,
        }) async {
          grants.add({
            'token': token,
            'gender': gender,
            'filters': _wire(filters),
            'reason': reason,
            'version': version,
            'previewHash': previewHash,
          });
          await grantGate?.future;
          final fail = grantFails;
          if (fail is PreviewChanged) grantFails = null;
          if (fail != null) throw fail;
        }),
        revokeAccessProvider.overrideWithValue(({
          required int id,
          required String reason,
          required String version,
        }) async {
          revokes.add({'id': id, 'reason': reason, 'version': version});
          await revokeGate?.future;
          if (revokeFails != null) throw revokeFails!;
        }),
      ],
      child: MaterialApp(
        home: pushed
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MemberClassAccessScreen(token: 300),
                    ),
                  ),
                  child: const Text('Go'),
                ),
              )
            : const MemberClassAccessScreen(token: 300),
      ),
    );

    Future<void> open(WidgetTester tester, {bool pushed = false}) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(pushed: pushed));
      await tester.pumpAndSettle();
      if (pushed) {
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
      }
    }

    Future<void> openSheetAndPreview(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Add class access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bilal'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview classes'));
      await tester.pumpAndSettle();
    }

    Future<void> confirmAdd(
      WidgetTester tester, {
      String reason = 'Covers',
    }) async {
      await tester.enterText(find.byType(TextField), reason);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add access'));
      await tester.pumpAndSettle();
    }

    Future<void> removeFirstRule(WidgetTester tester) async {
      await tester.tap(find.text('Gents, levels Bilal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Desk closed');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove access'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists each rule, expandable to the classes it reaches', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Ali Member'), findsOneWidget);
      expect(find.text('Gents, levels Bilal'), findsOneWidget);
      expect(find.text('Bilal 2'), findsNothing);

      await tester.tap(find.text('Gents, levels Bilal'));
      await tester.pumpAndSettle();

      expect(find.text('Bilal 2'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Remove'), findsOneWidget);
    });

    testWidgets('a role that already reaches classes is said in one line', (
      tester,
    ) async {
      viewNow = () =>
          _view(rules: const [], fromRole: 'Reaches every Gents class');
      await open(tester);

      expect(find.text('Reaches every Gents class'), findsOneWidget);
    });

    testWidgets('no access yet says so and offers to add it', (tester) async {
      viewNow = () => _view(rules: const []);
      await open(tester);

      expect(find.textContaining('does not manage any class'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Add class access'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load can be tried again', (tester) async {
      viewNow = () => throw const ApiException('x', 0);
      await open(tester);

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('previews the classes, needs a reason, sends the shown ids', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add class access'));
      await tester.pumpAndSettle();

      expect(find.text('Gents'), findsOneWidget, reason: 'one gender is fixed');
      final preview = find.widgetWithText(OutlinedButton, 'Preview classes');
      expect(tester.widget<OutlinedButton>(preview).onPressed, isNull);

      await tester.tap(find.widgetWithText(FilterChip, 'Bilal'));
      await tester.pump();
      await tester.tap(preview);
      await tester.pumpAndSettle();

      expect(previews, [
        {'gender': 1, 'filters': _levelFilter},
      ]);
      expect(find.text('Ammar 1'), findsOneWidget);
      final add = find.widgetWithText(FilledButton, 'Add access');
      expect(tester.widget<FilledButton>(add).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(add).onPressed, isNull);

      await confirmAdd(tester, reason: 'Covers Ammar');

      expect(grants, [
        {
          'token': 300,
          'gender': 1,
          'filters': _levelFilter,
          'reason': 'Covers Ammar',
          'version': '0:3',
          'previewHash': 'h1',
        },
      ]);
      expect(views, 2, reason: 'the member is read again');
      expect(find.text('Add access'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('a chosen city goes into the preview and the grant', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add class access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bilal'));
      await tester.tap(find.widgetWithText(FilterChip, 'Pune'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview classes'));
      await tester.pumpAndSettle();

      const withCity = [
        {
          'field': 'level',
          'values': [5],
        },
        {
          'field': 'city',
          'values': ['Pune'],
        },
      ];
      expect(previews.single['filters'], withCity);

      await confirmAdd(tester, reason: 'Pune only');
      expect(grants.single['filters'], withCity);
    });

    testWidgets('a chosen country goes into the preview and the grant', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add class access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bilal'));
      await tester.tap(find.widgetWithText(FilterChip, 'UAE'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview classes'));
      await tester.pumpAndSettle();

      const withCountry = [
        {
          'field': 'level',
          'values': [5],
        },
        {
          'field': 'country',
          'values': ['UAE'],
        },
      ];
      expect(previews.single['filters'], withCountry);

      await confirmAdd(tester, reason: 'UAE only');
      expect(grants.single['filters'], withCountry);
    });

    testWidgets('a chosen tag goes into the preview and the grant', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add class access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bilal'));
      await tester.tap(find.widgetWithText(FilterChip, 'Mumbra'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Preview classes'));
      await tester.pumpAndSettle();

      const withTag = [
        {
          'field': 'level',
          'values': [5],
        },
        {
          'field': 'tag',
          'values': ['Mumbra'],
        },
      ];
      expect(previews.single['filters'], withTag);

      await confirmAdd(tester, reason: 'Mumbra only');
      expect(grants.single['filters'], withTag);
    });

    testWidgets('changing the country or tag drops the shown preview', (
      tester,
    ) async {
      await open(tester);
      await openSheetAndPreview(tester);
      expect(find.text('Ammar 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'India'));
      await tester.pump();
      expect(find.text('Ammar 1'), findsNothing);
    });

    testWidgets('changing the city drops the shown preview', (tester) async {
      await open(tester);
      await openSheetAndPreview(tester);
      expect(find.text('Ammar 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Dubai'));
      await tester.pump();

      expect(find.text('Ammar 1'), findsNothing);
      expect(find.text('Add access'), findsNothing);
    });

    testWidgets('no city chosen sends the levels alone', (tester) async {
      await open(tester);
      await openSheetAndPreview(tester);

      expect(previews.single['filters'], _levelFilter);
    });

    testWidgets('a rule limited to a city says so in the member view', (
      tester,
    ) async {
      viewNow = () => _view(
        rules: const [
          AccessRule(
            id: 4,
            note: 'Gents, level Bilal, Pune, India, Mumbra',
            createdAt: '2026-10-01T10:00:00',
            classCount: 1,
            classes: [_bilal2],
          ),
        ],
      );
      await open(tester);

      expect(
        find.text('Gents, level Bilal, Pune, India, Mumbra'),
        findsOneWidget,
      );
    });

    testWidgets('preview_changed replaces the list and asks again', (
      tester,
    ) async {
      grantFails = const PreviewChanged(
        ClassPreview(classes: [_ammar1, _bilal2], count: 2, previewHash: 'h2'),
      );
      await open(tester);
      await openSheetAndPreview(tester);
      await confirmAdd(tester);

      expect(find.text('Bilal 2'), findsWidgets);
      expect(find.textContaining('classes changed'), findsOneWidget);
      expect(views, 1, reason: 'nothing saved, nothing reloaded');

      await tester.tap(find.widgetWithText(FilledButton, 'Add access'));
      await tester.pumpAndSettle();

      expect(grants.last['previewHash'], 'h2');
      expect(grants.last['reason'], 'Covers');
      expect(views, 2);
    });

    testWidgets('member_changed says so, closes the sheet and reloads', (
      tester,
    ) async {
      grantFails = const MemberChanged();
      await open(tester);
      await openSheetAndPreview(tester);
      await confirmAdd(tester);

      expect(find.text(_staleMessage), findsOneWidget);
      expect(find.text('Add access'), findsNothing);
      expect(views, 2);
    });

    testWidgets('a failed save says nothing changed and keeps the sheet', (
      tester,
    ) async {
      grantFails = const ApiException('Nothing was changed', 500);
      await open(tester);
      await openSheetAndPreview(tester);
      await confirmAdd(tester);

      expect(find.textContaining('cannot be saved'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add access'), findsOneWidget);
      expect(find.text('Ammar 1'), findsOneWidget);
      expect(views, 1);
    });

    testWidgets('a refusal shows the server words in the sheet', (
      tester,
    ) async {
      grantFails = const ApiException(
        'This member already has this access',
        409,
      );
      await open(tester);
      await openSheetAndPreview(tester);
      await confirmAdd(tester);

      expect(find.text('This member already has this access'), findsOneWidget);
      expect(views, 1);
    });

    testWidgets('a removal needs a reason and a confirmation', (tester) async {
      await open(tester);

      await tester.tap(find.text('Gents, levels Bilal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Remove access');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Desk closed');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(revokes, [
        {'id': 3, 'reason': 'Desk closed', 'version': '0:3'},
      ]);
      expect(views, 2);
    });

    testWidgets('a removal that was stale says so and reloads', (tester) async {
      revokeFails = const MemberChanged();
      await open(tester);
      await removeFirstRule(tester);

      expect(find.text(_staleMessage), findsOneWidget);
      expect(views, 2);
    });

    testWidgets('a failed removal says nothing changed', (tester) async {
      revokeFails = const ApiException('boom', 500);
      await open(tester);
      await removeFirstRule(tester);

      expect(find.textContaining('cannot be saved'), findsOneWidget);
      expect(views, 1);
    });

    testWidgets('classCount above the listed classes is the number shown', (
      tester,
    ) async {
      previewAnswer = const ClassPreview(
        classes: [_ammar1],
        count: 250,
        previewHash: 'h9',
      );
      await open(tester);
      await openSheetAndPreview(tester);

      expect(find.text('Reaches 250 classes'), findsOneWidget);
      expect(find.text('and 249 more'), findsOneWidget);
      await confirmAdd(tester);
      expect(grants.single['previewHash'], 'h9');
    });

    testWidgets('preview_changed keeps the reason that was typed', (
      tester,
    ) async {
      grantFails = const PreviewChanged(
        ClassPreview(classes: [_ammar1, _bilal2], count: 2, previewHash: 'h2'),
      );
      await open(tester);
      await openSheetAndPreview(tester);
      await confirmAdd(tester, reason: 'Because');

      expect(find.text('Because'), findsOneWidget);
    });

    testWidgets('a double tap on Add access sends one request', (tester) async {
      grantGate = Completer<void>();
      await open(tester);
      await openSheetAndPreview(tester);
      await tester.enterText(find.byType(TextField), 'Covers');
      await tester.pump();
      final add = find.widgetWithText(FilledButton, 'Add access');
      await tester.tap(add);
      await tester.tap(add);
      await tester.pump();

      expect(grants, hasLength(1));
      grantGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a sheet dismissed mid-save still reloads the member', (
      tester,
    ) async {
      grantGate = Completer<void>();
      await open(tester);
      await openSheetAndPreview(tester);
      await tester.enterText(find.byType(TextField), 'Covers');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add access'));
      await tester.pump();
      await tester.tapAt(const Offset(450, 20));
      await tester.pumpAndSettle();
      expect(find.text('Add access'), findsNothing);

      grantGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(views, 2);
    });

    testWidgets('Remove is disabled while a removal is in flight', (
      tester,
    ) async {
      revokeGate = Completer<void>();
      await open(tester);
      await removeFirstRule(tester);

      expect(revokes, hasLength(1));
      final remove = find.widgetWithText(TextButton, 'Remove');
      expect(tester.widget<TextButton>(remove).onPressed, isNull);

      revokeGate!.complete();
      await tester.pumpAndSettle();
      expect(views, 2);
    });

    testWidgets('leaving mid-removal is safe when it then succeeds', (
      tester,
    ) async {
      revokeGate = Completer<void>();
      await open(tester, pushed: true);
      await removeFirstRule(tester);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      revokeGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving mid-removal is safe when it was stale', (
      tester,
    ) async {
      revokeGate = Completer<void>();
      revokeFails = const MemberChanged();
      await open(tester, pushed: true);
      await removeFirstRule(tester);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      revokeGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('an already removed access reloads so the rule goes', (
      tester,
    ) async {
      revokeFails = const ApiException('That access was already removed', 409);
      await open(tester);
      await removeFirstRule(tester);

      expect(find.text('That access was already removed'), findsOneWidget);
      expect(views, 2);
    });
  });

  group('admin entry', () {
    Future<void> pumpAdmin(WidgetTester tester, List<String> held) {
      return tester.pumpWidget(
        ProviderScope(
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
    }

    testWidgets('the card shows for class-access:manage', (tester) async {
      await pumpAdmin(tester, ['class-access:manage:gender']);
      await tester.pumpAndSettle();

      expect(find.text('Class admins'), findsOneWidget);
    });

    testWidgets('the card is hidden without the permission', (tester) async {
      await pumpAdmin(tester, ['reports:read:gender']);
      await tester.pumpAndSettle();

      expect(find.text('Class admins'), findsNothing);
    });
  });
}
