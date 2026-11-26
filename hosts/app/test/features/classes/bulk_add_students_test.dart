import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/classes/models/bulk_add.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';
import 'package:the_strong_rope/features/classes/widgets/manage_students_tab.dart';

Map<String, dynamic> _payload({required bool enrol}) => {
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
    'enrol': enrol,
    'setClassAdmin': false,
    'transfer': false,
  },
  'students': <dynamic>[],
  'removedStudents': <dynamic>[],
  'mcqStudents': <dynamic>[],
  'transferHistory': null,
  'destinations': null,
};

class _FakeRepository extends ClassManageRepository {
  final bool enrol;

  /// What each call answers, in order.
  final List<Object> answers;
  final List<({List<String> lines, Map<int, String> resolutions})> calls = [];

  _FakeRepository({required this.enrol, this.answers = const []});

  @override
  Future<ClassManagePayload> getManage(int classId) async =>
      ClassManagePayload.fromJson(_payload(enrol: enrol));

  @override
  Future<BulkAddResult> bulkAddStudents(
    int classId,
    List<String> lines,
    Map<int, String> resolutions,
  ) async {
    calls.add((lines: lines, resolutions: resolutions));
    final answer = answers[calls.length - 1];
    if (answer is Exception) throw answer;
    return answer as BulkAddResult;
  }
}

BulkLineResult _line(
  int n,
  String name,
  String status, {
  String? reason,
  String? member,
}) => BulkLineResult(
  line: n,
  name: name,
  status: status,
  reason: reason,
  memberName: member,
);

Future<void> _open(WidgetTester tester, _FakeRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [classManageRepositoryProvider.overrideWithValue(repo)],
      // The screen shows the tab only once the payload is loaded; so does this.
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

Future<void> _openDialog(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('bulk-add-students')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('bulk-add-field')), text);
  await tester.pump();
}

void main() {
  testWidgets('the option is hidden without permission to enrol', (
    tester,
  ) async {
    await _open(tester, _FakeRepository(enrol: false));

    expect(find.byKey(const Key('bulk-add-students')), findsNothing);
  });

  testWidgets('the option is offered to someone who may enrol', (tester) async {
    await _open(tester, _FakeRepository(enrol: true));

    expect(find.byKey(const Key('bulk-add-students')), findsOneWidget);
  });

  testWidgets('Add stays disabled until a line is typed', (tester) async {
    await _open(tester, _FakeRepository(enrol: true));
    await tester.tap(find.byKey(const Key('bulk-add-students')));
    await tester.pumpAndSettle();

    FilledButton submit() =>
        tester.widget<FilledButton>(find.byKey(const Key('bulk-add-submit')));
    expect(submit().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('bulk-add-field')), '  \n  ');
    await tester.pump();
    expect(submit().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('bulk-add-field')), 'Ali');
    await tester.pump();
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('sends the non-blank lines and shows a result for each', (
    tester,
  ) async {
    final repo = _FakeRepository(
      enrol: true,
      answers: [
        BulkAddResult(
          status: 'added',
          added: 1,
          lines: [
            _line(1, 'Ali Khan', 'added'),
            _line(
              2,
              'Bad Mobile',
              'rejected',
              reason: 'The mobile number is not valid.',
            ),
          ],
          roster: const ManageRoster(),
        ),
      ],
    );
    await _open(tester, repo);
    await _openDialog(tester, 'Ali Khan, 9800000000\n\n  Bad Mobile, 12ab  \n');
    await tester.tap(find.byKey(const Key('bulk-add-submit')));
    await tester.pumpAndSettle();

    expect(repo.calls.single.lines, [
      'Ali Khan, 9800000000',
      'Bad Mobile, 12ab',
    ]);
    expect(repo.calls.single.resolutions, isEmpty);
    expect(find.text('Added 1 student(s).'), findsOneWidget);
    expect(find.text('Line 1: Ali Khan'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Line 2: Bad Mobile'), findsOneWidget);
    expect(
      find.text('Not added. The mobile number is not valid.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('bulk-add-done')));
    await tester.pumpAndSettle();
    expect(find.text('1 student(s) added'), findsOneWidget);
  });

  testWidgets('when every line is invalid it says so and lets the user edit', (
    tester,
  ) async {
    final repo = _FakeRepository(
      enrol: true,
      answers: [
        BulkAddResult(
          status: 'none',
          added: 0,
          lines: [_line(1, '', 'rejected', reason: 'The name is missing.')],
        ),
      ],
    );
    await _open(tester, repo);
    await _openDialog(tester, ', 9800000000');
    await tester.tap(find.byKey(const Key('bulk-add-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nobody was added. Fix the lines below and try again.'),
      findsOneWidget,
    );
    expect(find.text('Not added. The name is missing.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bulk-add-back')));
    await tester.pumpAndSettle();
    expect(find.text(', 9800000000'), findsOneWidget);
  });

  testWidgets('flagged lines wait for a choice, then the list is sent again', (
    tester,
  ) async {
    final repo = _FakeRepository(
      enrol: true,
      answers: [
        BulkAddResult(
          status: 'confirm',
          added: 0,
          lines: [
            _line(1, 'Same Name', 'duplicate_name'),
            _line(2, 'Someone Else', 'mobile_match', member: 'Gents Member'),
            _line(3, 'Fresh', 'ready'),
          ],
        ),
        BulkAddResult(
          status: 'added',
          added: 2,
          lines: [
            _line(1, 'Same Name', 'rejected', reason: 'Skipped.'),
            _line(2, 'Someone Else', 'enrolled'),
            _line(3, 'Fresh', 'added'),
          ],
          roster: const ManageRoster(),
        ),
      ],
    );
    await _open(tester, repo);
    await _openDialog(tester, 'Same Name\nSomeone Else, 9800000002\nFresh');
    await tester.tap(find.byKey(const Key('bulk-add-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing has been added yet.'), findsOneWidget);
    expect(find.textContaining('belongs to Gents Member'), findsOneWidget);
    expect(
      find.textContaining('"Same Name" is already in this class'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('bulk-add-continue')));
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(2));
    expect(repo.calls[1].lines, repo.calls[0].lines);
    expect(repo.calls[1].resolutions, {1: 'skip', 2: 'enrol'});
    expect(find.text('Added 2 student(s).'), findsOneWidget);
    expect(find.text('Existing member enrolled'), findsOneWidget);
  });

  testWidgets('a choice the user changes is the one sent', (tester) async {
    final repo = _FakeRepository(
      enrol: true,
      answers: [
        BulkAddResult(
          status: 'confirm',
          added: 0,
          lines: [_line(1, 'Same Name', 'duplicate_name')],
        ),
        BulkAddResult(
          status: 'added',
          added: 1,
          lines: [_line(1, 'Same Name', 'added')],
          roster: const ManageRoster(),
        ),
      ],
    );
    await _open(tester, repo);
    await _openDialog(tester, 'Same Name');
    await tester.tap(find.byKey(const Key('bulk-add-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add anyway'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bulk-add-continue')));
    await tester.pumpAndSettle();

    expect(repo.calls[1].resolutions, {1: 'add'});
  });

  testWidgets('a failure says nothing was added and keeps the list', (
    tester,
  ) async {
    final repo = _FakeRepository(
      enrol: true,
      answers: [
        const ApiException('Nothing was added. Please try again.', 500),
      ],
    );
    await _open(tester, repo);
    await _openDialog(tester, 'Ali Khan');
    await tester.tap(find.byKey(const Key('bulk-add-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk-add-error')), findsOneWidget);
    expect(find.textContaining('Nothing was added.'), findsOneWidget);
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.byKey(const Key('bulk-add-submit')), findsOneWidget);
  });
}
