import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';
import 'package:the_strong_rope/features/classes/widgets/manage_students_tab.dart';

const _linkLabel = 'Link to an existing member';

Map<String, dynamic> _payload({
  required bool canLink,
  required bool extraStudent,
}) => {
  'class': {
    'id': 27,
    'code': 'AY-7',
    'name': 'Sulsi',
    'levelId': 4,
    'levelName': 'AMMAR',
    'gender': 1,
    'genderName': 'Gents',
    'teacher': 12757,
  },
  'tags': <dynamic>[],
  'schedules': <dynamic>[],
  'lookups': <String, dynamic>{},
  'can': {
    'update': true,
    'enrol': true,
    'setClassAdmin': false,
    'transfer': false,
    'link': canLink,
  },
  'students': [
    {'token': 5001, 'name': 'Extra Eve', 'extraStudent': extraStudent},
  ],
  'removedStudents': <dynamic>[],
  'mcqStudents': <dynamic>[],
  'transferHistory': null,
  'destinations': null,
};

Map<String, dynamic> _conflict(int itemId, String label) => {
  'kind': 'attendance',
  'itemId': itemId,
  'classCode': 'AY-7',
  'label': label,
  'member': {'present': true, 'recitation': 'Fatiha'},
  'extra': {'present': false, 'recitation': null},
};

Map<String, dynamic> _preview({
  List<Map<String, dynamic>> conflicts = const [],
}) => {
  'member': {
    'token': 7001,
    'name': 'Real Member',
    'gender': 1,
    'email': 'member@example.com',
    'mobile': null,
    'city': 'Mumbai',
    'country': 'India',
    'registeredOn': '2026-01-02',
    'requestedClass': null,
    'classesNow': [
      {'id': 9, 'code': 'MB-1', 'name': 'Other class', 'level': 'BILAL'},
    ],
    'classesLeft': <dynamic>[],
  },
  'extra': {
    'token': 5001,
    'name': 'Extra Eve',
    'classes': [
      {'id': 27, 'code': 'AY-7', 'name': 'Sulsi', 'current': true},
    ],
  },
  'conflicts': conflicts,
};

class _FakeApi implements ApiClient {
  final List<(String, Object?)> posts = [];
  ApiException? failure;

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path, data));
    final error = failure;
    if (error != null) throw error;
    return <String, dynamic>{'linked': true} as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository extends ClassManageRepository {
  final bool canLink;
  final bool extraStudent;

  /// What each preview call answers, in order: a map, or an exception.
  final List<Object> previews;

  /// What the link call throws, if anything.
  final Object? linkFailure;
  int getManageCalls = 0;
  final List<int> previewCalls = [];
  final List<({int extra, int member, List<LinkResolution> resolutions})>
  linkCalls = [];

  _FakeRepository({
    this.canLink = true,
    this.extraStudent = true,
    this.previews = const [],
    this.linkFailure,
  });

  @override
  Future<ClassManagePayload> getManage(int classId) async {
    getManageCalls++;
    return ClassManagePayload.fromJson(
      _payload(canLink: canLink, extraStudent: extraStudent),
    );
  }

  @override
  Future<LinkPreview> linkPreview(int extraToken, int memberToken) async {
    previewCalls.add(memberToken);
    final answer = previews[previewCalls.length - 1];
    if (answer is Exception) throw answer;
    return LinkPreview.fromJson(answer as Map<String, dynamic>);
  }

  @override
  Future<void> linkStudent(
    int extraToken,
    int memberToken,
    List<LinkResolution> resolutions,
  ) async {
    linkCalls.add((
      extra: extraToken,
      member: memberToken,
      resolutions: resolutions,
    ));
    final failure = linkFailure;
    if (failure != null) throw failure;
  }
}

Future<void> _open(WidgetTester tester, _FakeRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [classManageRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) =>
                ref.watch(classManageProvider(27)).payload == null
                ? const SizedBox()
                : const ManageStudentsTab(classId: 27),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditDialog(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit details'));
  await tester.pumpAndSettle();
}

Future<void> _findMember(WidgetTester tester, {String token = '7001'}) async {
  await tester.tap(find.text(_linkLabel));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('link-token-field')), token);
  await tester.pump();
  await tester.tap(find.byKey(const Key('link-find')));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, int itemId, String label) async {
  final row = find.byKey(Key('link-choice-attendance-$itemId'));
  await tester.ensureVisible(row);
  await tester.tap(find.descendant(of: row, matching: find.text(label)));
  await tester.pumpAndSettle();
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('link-confirm')));

void main() {
  testWidgets(
    'Edit student offers link only to super admin for extra student',
    (tester) async {
      for (final (canLink, extra) in [
        (true, true),
        (true, false),
        (false, true),
        (false, false),
      ]) {
        await _open(
          tester,
          _FakeRepository(canLink: canLink, extraStudent: extra),
        );
        await _openEditDialog(tester);

        expect(
          find.text(_linkLabel),
          canLink && extra ? findsOneWidget : findsNothing,
          reason: 'canLink=$canLink extraStudent=$extra',
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('shows the preview and asks to confirm', (tester) async {
    final repo = _FakeRepository(previews: [_preview()]);
    await _open(tester, repo);
    await _openEditDialog(tester);
    await _findMember(tester);

    expect(repo.previewCalls, [7001]);
    expect(find.text('Real Member'), findsOneWidget);
    expect(find.textContaining('MB-1'), findsOneWidget);
    expect(find.textContaining('AY-7'), findsOneWidget);
    expect(repo.linkCalls, isEmpty);
    expect(repo.getManageCalls, 1);

    await tester.tap(find.byKey(const Key('link-confirm')));
    await tester.pumpAndSettle();

    expect(repo.linkCalls, hasLength(1));
    expect(repo.linkCalls.single.extra, 5001);
    expect(repo.linkCalls.single.member, 7001);
    expect(repo.linkCalls.single.resolutions, isEmpty);
    expect(repo.getManageCalls, 2, reason: 'the roster is refreshed');
  });

  testWidgets('confirm waits for every conflict choice', (tester) async {
    final repo = _FakeRepository(
      previews: [
        _preview(
          conflicts: [_conflict(11, 'Monday'), _conflict(12, 'Tuesday')],
        ),
      ],
    );
    await _open(tester, repo);
    await _openEditDialog(tester);
    await _findMember(tester);

    expect(_confirm(tester).onPressed, isNull);

    await _choose(tester, 11, "Keep member's");
    expect(_confirm(tester).onPressed, isNull);

    await _choose(tester, 12, "Keep extra student's");
    expect(_confirm(tester).onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('link-confirm')));
    await tester.tap(find.byKey(const Key('link-confirm')));
    await tester.pumpAndSettle();

    final sent = repo.linkCalls.single.resolutions;
    expect(sent.map((r) => (r.kind, r.itemId, r.keep)), [
      ('attendance', 11, 'member'),
      ('attendance', 12, 'extra'),
    ]);
  });

  testWidgets('records_changed shows the fresh preview and clears choices', (
    tester,
  ) async {
    final repo = _FakeRepository(
      previews: [
        _preview(conflicts: [_conflict(11, 'Monday')]),
      ],
      linkFailure: LinkRecordsChanged(
        'The records changed. Check the new list and choose again.',
        LinkPreview.fromJson(
          _preview(
            conflicts: [_conflict(11, 'Monday'), _conflict(13, 'Wednesday')],
          ),
        ),
      ),
    );
    await _open(tester, repo);
    await _openEditDialog(tester);
    await _findMember(tester);
    await _choose(tester, 11, "Keep member's");
    await tester.ensureVisible(find.byKey(const Key('link-confirm')));
    await tester.tap(find.byKey(const Key('link-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('records changed'), findsOneWidget);
    expect(find.byKey(const Key('link-choice-attendance-13')), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull, reason: 'choices were cleared');
  });

  testWidgets('refusal shows its reason', (tester) async {
    final repo = _FakeRepository(
      previews: [
        ApiException(
          'The member must be a different person from the extra student',
          422,
          body: {'code': 'same_student'},
        ),
      ],
    );
    await _open(tester, repo);
    await _openEditDialog(tester);
    await _findMember(tester, token: '5001');

    expect(
      find.text('The member must be a different person from the extra student'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('link-confirm')), findsNothing);
    expect(repo.linkCalls, isEmpty);
  });

  testWidgets('a refused link shows the reason and keeps the preview', (
    tester,
  ) async {
    final repo = _FakeRepository(
      previews: [_preview()],
      linkFailure: ApiException(
        'This student is not an extra student',
        409,
        body: {'code': 'not_extra_student'},
      ),
    );
    await _open(tester, repo);
    await _openEditDialog(tester);
    await _findMember(tester);
    await tester.tap(find.byKey(const Key('link-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('This student is not an extra student'), findsOneWidget);
    expect(find.text('Real Member'), findsOneWidget);
    expect(repo.getManageCalls, 1, reason: 'nothing changed, no refresh');
  });

  group('repository', () {
    test('sends the resolutions to the link route', () async {
      final api = _FakeApi();
      await ClassManageRepository(apiClient: api).linkStudent(5001, 7001, [
        const LinkResolution(kind: 'attendance', itemId: 11, keep: 'member'),
      ]);

      expect(api.posts.single.$1, '/admin/extra-students/5001/link/7001');
      expect(api.posts.single.$2, {
        'resolutions': [
          {'kind': 'attendance', 'itemId': 11, 'keep': 'member'},
        ],
      });
    });

    test('a 409 records_changed carries the fresh preview', () async {
      final api = _FakeApi()
        ..failure = ApiException(
          'The records changed.',
          409,
          body: {
            'code': 'records_changed',
            'preview': _preview(conflicts: [_conflict(13, 'Wednesday')]),
          },
        );

      await expectLater(
        ClassManageRepository(apiClient: api).linkStudent(5001, 7001, []),
        throwsA(
          isA<LinkRecordsChanged>().having(
            (e) => e.preview.conflicts.single.itemId,
            'fresh conflict',
            13,
          ),
        ),
      );
    });

    test('any other refusal is passed on untouched', () async {
      final api = _FakeApi()
        ..failure = ApiException(
          'Not an extra student',
          409,
          body: {'code': 'not_extra_student'},
        );

      await expectLater(
        ClassManageRepository(apiClient: api).linkStudent(5001, 7001, []),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
