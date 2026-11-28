import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/this_week.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/this_week_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(gender: 1),
        issuedAt: '',
      ),
    );
  }
}

ThisWeekRow _row(
  int id,
  String code, {
  String detail = '',
  String? action,
  String? mobile = '+91 90000 00001',
  List<QuietSubject> quiet = const [],
}) => ThisWeekRow(
  classId: id,
  code: code,
  level: 'MIQDAD',
  teacher: 'Teacher $id',
  teacherMobile: mobile,
  detail: detail,
  action: action,
  quiet: quiet,
);

ThisWeek _screen({bool allClear = false}) => ThisWeek(
  gender: 1,
  weekFrom: '2026-10-11',
  weekTo: '2026-10-17',
  summary: ThisWeekSummary(
    met: allClear ? 4 : 3,
    total: 4,
    formsMissing: allClear ? 0 : 1,
    attendance: 0.62,
    flagged: allClear ? 0 : 3,
  ),
  cform: allClear
      ? const []
      : [_row(3, 'C1', detail: 'Form not submitted', action: 'message')],
  conduction: allClear
      ? const []
      : [
          _row(1, 'A1', detail: 'No class for 4 weeks', action: 'call'),
          _row(
            2,
            'A2',
            action: 'message',
            mobile: null,
            quiet: const [QuietSubject(subject: 'ahkam', weeks: 2)],
          ),
        ],
  attendance: allClear
      ? const []
      : [_row(1, 'A1', detail: 'Attendance 40%', action: 'message')],
  alignment: [_row(1, 'A1'), _row(2, 'A2')],
  met: allClear
      ? [
          _row(1, 'A1', detail: 'Met', mobile: null),
          _row(2, 'A2', detail: 'Met', mobile: null),
          _row(4, 'A4', detail: 'Met', mobile: null),
          _row(5, 'A5', detail: 'Met', mobile: null),
        ]
      : [
          _row(1, 'A1', detail: 'Met', mobile: null),
          _row(2, 'A2', detail: 'Met', mobile: null),
          _row(4, 'A4', detail: 'Met', mobile: null),
        ],
  attended: [
    _row(1, 'A1', detail: 'Attendance 40%', mobile: null),
    _row(2, 'A2', detail: 'Attendance 90%', mobile: null),
  ],
);

const _alignment = ClassAlignment(
  classId: 1,
  code: 'A1',
  level: 'MIQDAD',
  weeks: [
    AlignmentWeek(
      from: '2026-10-11',
      to: '2026-10-17',
      status: 'taught',
      subjects: {'ahkam': 'Wuzu', 'aqaed': 'Tauheed'},
    ),
    AlignmentWeek(
      from: '2026-10-04',
      to: '2026-10-10',
      status: 'no form',
      subjects: {},
    ),
  ],
  chart: {
    'ahkam': {
      'Wuzu': ['Step one'],
    },
  },
);

Widget _wrap({
  Future<ThisWeek> Function(int?)? load,
  Future<ClassAlignment> Function(int)? alignment,
  List<Uri>? launched,
  bool reachesBoth = false,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith(
        (ref) => _FixedPermissions([
          reachesBoth ? 'reports:read:all' : 'reports:read:gender',
        ]),
      ),
      thisWeekProvider.overrideWith(
        (ref, gender) => (load ?? (_) async => _screen())(gender),
      ),
      classAlignmentProvider.overrideWith(
        (ref, id) => (alignment ?? (_) async => _alignment)(id),
      ),
      thisWeekLaunchProvider.overrideWithValue((uri) async {
        launched?.add(uri);
        return true;
      }),
    ],
    child: const MaterialApp(home: ThisWeekScreen()),
  );
}

Finder _in(String key, Finder matching) =>
    find.descendant(of: find.byKey(Key(key)), matching: matching);

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(900, 4000);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  testWidgets('the stages appear in the spec order under the summary strip', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('3 of 4 met'), findsOneWidget);
    expect(find.text('62% attended'), findsOneWidget);
    expect(find.text('3 flagged'), findsOneWidget);

    final order = [
      for (final title in ['C-form', 'Conduction', 'Attendance', 'Alignment'])
        tester.getTopLeft(find.text(title)).dy,
    ];
    expect(order, [...order]..sort());
    expect(order.toSet().length, 4);
  });

  testWidgets('Call opens the dialer on the teacher\'s number', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(_wrap(launched: launched));
    await tester.pumpAndSettle();

    await tester.tap(_in('row-conduction-1', find.text('Call')));
    await tester.pumpAndSettle();

    expect(launched.single.toString(), 'tel:+919000000001');
  });

  testWidgets(
    'Message opens WhatsApp on that teacher with a note naming the class',
    (tester) async {
      final launched = <Uri>[];
      await tester.pumpWidget(_wrap(launched: launched));
      await tester.pumpAndSettle();

      await tester.tap(_in('row-cform-3', find.text('Message')));
      await tester.pumpAndSettle();

      final uri = launched.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919000000001');
      expect(uri.queryParameters['text'], contains('C1'));
      expect(uri.queryParameters['text'], contains('Form not submitted'));
    },
  );

  testWidgets('a bare ten-digit number is dialled with the country code', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      _wrap(
        launched: launched,
        load: (_) async => ThisWeek(
          gender: 1,
          weekFrom: '2026-10-11',
          weekTo: '2026-10-17',
          summary: const ThisWeekSummary(
            met: 0,
            total: 1,
            formsMissing: 0,
            attendance: null,
            flagged: 1,
          ),
          cform: const [],
          conduction: [
            _row(
              1,
              'A1',
              detail: 'No class for 4 weeks',
              action: 'call',
              mobile: '9000000001',
            ),
          ],
          attendance: const [],
          alignment: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_in('row-conduction-1', find.text('Call')));
    await tester.tap(_in('row-conduction-1', find.text('Message')));
    await tester.pumpAndSettle();

    expect(launched.first.toString(), 'tel:+919000000001');
    expect(launched.last.path, '/919000000001');
  });

  testWidgets('the summary says how many forms are missing', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('1 form missing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(load: (_) async => _screen(allClear: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('missing'), findsNothing);
  });

  testWidgets(
    'a two-week gap offers a message only, a longer one adds a call',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(_in('row-conduction-1', find.text('Call')), findsOneWidget);
      expect(_in('row-conduction-1', find.text('Message')), findsOneWidget);
      expect(_in('row-cform-3', find.text('Call')), findsNothing);
      expect(_in('row-cform-3', find.text('Message')), findsOneWidget);
    },
  );

  testWidgets('a row with no teacher number has no buttons', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(_in('row-conduction-2', find.text('Call')), findsNothing);
    expect(_in('row-conduction-2', find.text('Message')), findsNothing);
    expect(_in('row-conduction-2', find.text('A2')), findsOneWidget);
  });

  testWidgets('a quiet subject is a line on the class row', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(
      _in('row-conduction-2', find.text('Ahkam: not taught for 2 weeks')),
      findsOneWidget,
    );
  });

  testWidgets('an empty week shows an all-clear message', (tester) async {
    await tester.pumpWidget(_wrap(load: (_) async => _screen(allClear: true)));
    await tester.pumpAndSettle();

    expect(find.text('All clear this week'), findsOneWidget);
    expect(find.text('C-form'), findsNothing);
  });

  testWidgets('tapping a class shows its eight weeks against the chart', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(_in('row-alignment-1', find.text('A1')));
    await tester.pumpAndSettle();

    expect(find.text('Wuzu'), findsOneWidget);
    expect(find.text('Tauheed'), findsOneWidget);
    expect(find.text('No form'), findsOneWidget);
    expect(find.text('Standard Syllabus Chart'), findsOneWidget);
  });

  testWidgets('a level with no chart shows what was taught and no comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        alignment: (_) async => const ClassAlignment(
          classId: 1,
          code: 'A1',
          level: 'AMMAR',
          weeks: [
            AlignmentWeek(
              from: '2026-10-11',
              to: '2026-10-17',
              status: 'taught',
              subjects: {'ahkam': 'Wuzu'},
            ),
          ],
          chart: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_in('row-alignment-1', find.text('A1')));
    await tester.pumpAndSettle();

    expect(find.text('Wuzu'), findsOneWidget);
    expect(find.text('Standard Syllabus Chart'), findsNothing);
    expect(find.text('No chart for this level yet'), findsOneWidget);
  });

  testWidgets('an error offers a retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        load: (_) async {
          calls++;
          if (calls == 1) throw Exception('boom');
          return _screen();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The weekly review could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('3 of 4 met'), findsOneWidget);
  });

  group('summary filters', () {
    Finder chip(String label) => find.widgetWithText(FilterChip, label);

    testWidgets('forms missing lists exactly the classes counted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(chip('1 form missing'));
      await tester.pumpAndSettle();

      expect(find.byType(Card).evaluate().length, greaterThan(0));
      expect(find.byKey(const Key('row-cform-3')), findsOneWidget);
      expect(find.byKey(const Key('stage-conduction')), findsNothing);
      expect(find.byKey(const Key('stage-attendance')), findsNothing);
      expect(find.byKey(const Key('stage-alignment')), findsNothing);
      // The count on the chip equals the rows listed.
      expect(find.byKey(const Key('stage-cform')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('stage-cform')),
          matching: find.byWidgetPredicate(
            (w) => w.key.toString().startsWith("[<'row-cform-"),
          ),
        ),
        findsNWidgets(1),
      );
    });

    testWidgets('flagged lists each flagged class once, with every reason', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(chip('3 flagged'));
      await tester.pumpAndSettle();

      for (final id in [1, 2, 3]) {
        expect(find.byKey(Key('row-flagged-$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('stage-alignment')), findsNothing);
      expect(
        _in('row-flagged-1', find.text('No class for 4 weeks; Attendance 40%')),
        findsOneWidget,
      );
      expect(_in('row-flagged-1', find.text('Message')), findsOneWidget);
    });

    testWidgets('while a filter is on it is named and can be cleared', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-indicator')), findsNothing);

      await tester.tap(chip('1 form missing'));
      await tester.pumpAndSettle();
      expect(find.text('Showing: forms missing'), findsOneWidget);
      expect(
        tester.widget<FilterChip>(chip('1 form missing')).selected,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('filter-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-indicator')), findsNothing);
      for (final stage in ['cform', 'conduction', 'attendance', 'alignment']) {
        expect(find.byKey(Key('stage-$stage')), findsOneWidget);
      }
    });

    testWidgets('tapping the selected number again clears the filter', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(chip('3 flagged'));
      await tester.pumpAndSettle();
      await tester.tap(chip('3 flagged'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter-indicator')), findsNothing);
      expect(find.byKey(const Key('stage-alignment')), findsOneWidget);
    });

    testWidgets('numbers with no rows behind them are plain text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(load: (_) async => _screen(allClear: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 flagged'), findsOneWidget);
      expect(chip('0 flagged'), findsNothing);
      expect(find.textContaining('forms missing'), findsNothing);
    });

    testWidgets('met lists exactly the classes counted in it', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(chip('3 of 4 met'));
      await tester.pumpAndSettle();

      expect(find.text('Showing: classes that met'), findsOneWidget);
      for (final id in [1, 2, 4]) {
        expect(find.byKey(Key('row-met-$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('stage-cform')), findsNothing);
      expect(find.byKey(const Key('stage-alignment')), findsNothing);
      // Criterion 1: the number and the list are the same count.
      expect(_in('stage-met', find.text('3')), findsOneWidget);
      // Nothing to call or message: these rows are to read.
      expect(find.text('Call'), findsNothing);
      expect(find.text('Message'), findsNothing);
    });

    testWidgets('attended lists the classes behind the average', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(chip('62% attended'));
      await tester.pumpAndSettle();

      expect(
        find.text('Showing: classes with attendance marked'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('row-attended-1')), findsOneWidget);
      expect(find.byKey(const Key('row-attended-2')), findsOneWidget);
      expect(find.text('Attendance 90%'), findsOneWidget);
      expect(find.byKey(const Key('stage-conduction')), findsNothing);
    });

    testWidgets('every number equals the rows in the list it opens', (
      tester,
    ) async {
      final screen = _screen();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final cases = {
        '3 of 4 met': ('stage-met', screen.summary.met),
        '1 form missing': ('stage-cform', screen.summary.formsMissing),
        '3 flagged': ('stage-flagged', screen.summary.flagged),
      };
      for (final entry in cases.entries) {
        await tester.tap(chip(entry.key));
        await tester.pumpAndSettle();
        final rows = find.descendant(
          of: find.byKey(Key(entry.value.$1)),
          matching: find.byType(Card),
        );
        expect(rows, findsNWidgets(entry.value.$2), reason: entry.key);
        await tester.tap(find.byKey(const Key('filter-clear')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a number with no rows behind it is plain text', (
      tester,
    ) async {
      final none = ThisWeek(
        gender: 1,
        weekFrom: '2026-10-11',
        weekTo: '2026-10-17',
        summary: const ThisWeekSummary(
          met: 0,
          total: 0,
          formsMissing: 0,
          attendance: null,
          flagged: 0,
        ),
        cform: const [],
        conduction: const [],
        attendance: const [],
        alignment: const [],
        met: const [],
        attended: const [],
      );
      await tester.pumpWidget(_wrap(load: (_) async => none));
      await tester.pumpAndSettle();

      expect(find.text('0 of 0 met'), findsOneWidget);
      expect(find.text('No attendance yet'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('a filter that leaves no rows says so and offers to clear', (
      tester,
    ) async {
      // Ladies has no forms missing: switching gender under a filter.
      await tester.pumpWidget(
        _wrap(
          reachesBoth: true,
          load: (gender) async =>
              gender == 2 ? _screen(allClear: true) : _screen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip('1 form missing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ladies'));
      await tester.pumpAndSettle();

      expect(find.text('No classes match this filter'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear filter').last);
      await tester.pumpAndSettle();
      expect(find.text('All clear this week'), findsOneWidget);
    });

    testWidgets('tappable numbers are 48dp tall and labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(
        tester.getSize(chip('1 form missing')).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        find.bySemanticsLabel('Show only: 1 form missing'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
