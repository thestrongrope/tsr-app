import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/class_detail_screen.dart';
import 'package:the_strong_rope/features/classes/screens/class_manage_screen.dart';
import 'package:the_strong_rope/features/classes/widgets/manage_students_tab.dart';

import '../../support/content_width.dart';

Widget _host(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: home,
      ),
    ),
  );
}

class _DetailRepository extends ClassesRepository {
  _DetailRepository(this._answer);

  final ClassModel Function() _answer;

  @override
  Future<ClassModel> getClassDetail(int classId) async => _answer();
}

class _RosterRepository extends ClassManageRepository {
  _RosterRepository({this.students = const [], this.failures = 0});

  final List<ManagedStudent> students;
  int failures;
  int calls = 0;

  @override
  Future<List<ManagedStudent>> getTeacherRoster(int classId) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const ApiException('Could not reach the server', 500);
    }
    return students;
  }
}

class _ManageRepository extends ClassManageRepository {
  @override
  Future<ClassManagePayload> getManage(int classId) async =>
      ClassManagePayload.fromJson({
        'class': {
          'id': 27,
          'code': 'AY-7',
          'name': 'Sulsi',
          'levelId': 4,
          'levelName': 'AMMAR',
          'gender': 1,
          'genderName': 'Gents',
          'teacher': 1,
        },
        'tags': <dynamic>[],
        'schedules': <dynamic>[],
        'lookups': <String, dynamic>{},
        'can': {
          'update': true,
          'enrol': true,
          'setClassAdmin': false,
          'transfer': true,
        },
        'students': <dynamic>[],
        'removedStudents': <dynamic>[],
        'mcqStudents': [
          {'token': 5, 'name': 'Quiz Taker'},
        ],
        'transferHistory': <dynamic>[],
        'destinations': <dynamic>[],
      });
}

void main() {
  group('class detail', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      final pending = Completer<ClassModel>();
      await tester.pumpWidget(
        _host(const ClassDetailScreen(classId: 10), [
          classDetailProvider(10).overrideWith((ref) => pending.future),
        ]),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    for (final size in [tabletLandscape, tabletPortrait]) {
      testWidgets('on a $size tablet the content is capped and centred', (
        tester,
      ) async {
        setWindow(tester, size);
        await tester.pumpWidget(
          _host(const ClassDetailScreen(classId: 10), [
            classDetailProvider(10).overrideWith(
              (ref) async => throw const ApiException('offline', 500),
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expectContentCapped(tester);
      });
    }

    testWidgets('a failure keeps the member on the class and retries', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(const ClassDetailScreen(classId: 10), [
          classDetailProvider(10).overrideWith((ref) async {
            calls++;
            throw const ApiException('Could not reach the server', 500);
          }),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Class Dashboard'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Class Dashboard'), findsOneWidget);
    });
  });

  test('reopening a class after a failed load fetches it again', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        classesRepositoryProvider.overrideWithValue(
          _DetailRepository(() {
            calls++;
            if (calls == 1) throw const ApiException('offline', 0);
            return const ClassModel(
              id: 10,
              code: 'C',
              name: 'Fiqh',
              level: 1,
              levelName: 'L',
              gender: 1,
              status: 'A',
            );
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final first = container.listen(classDetailProvider(10), (_, _) {});
    await expectLater(
      container.read(classDetailProvider(10).future),
      throwsA(isA<ApiException>()),
    );
    first.close();
    await Future<void>.delayed(Duration.zero);

    final reopened = await container.read(classDetailProvider(10).future);
    expect(reopened.name, 'Fiqh');
    expect(calls, 2);
  });

  group('class students', () {
    Future<void> openRoster(WidgetTester tester, _RosterRepository repo) async {
      await tester.pumpWidget(
        _host(const ClassRosterScreen(classId: 10), [
          classManageRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a class with no students says so', (tester) async {
      await openRoster(tester, _RosterRepository());

      expect(find.text('No students in this class.'), findsOneWidget);
    });

    testWidgets('a failure offers Retry that loads the roster again', (
      tester,
    ) async {
      final repo = _RosterRepository(
        failures: 1,
        students: const [ManagedStudent(token: 1, name: 'Ann')],
      );
      await openRoster(tester, repo);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Class students'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('Ann'), findsOneWidget);
    });

    testWidgets('every filter label shows in full on a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          Consumer(
            builder: (context, ref, _) =>
                ref.watch(classManageProvider(27)).payload == null
                ? const SizedBox()
                : const Scaffold(body: ManageStudentsTab(classId: 27)),
          ),
          [
            classManageRepositoryProvider.overrideWithValue(
              _ManageRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Active (0)',
        'Removed (0)',
        'Quiz takers (1)',
        'Transfers',
      ]) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        // One line, nothing cut: a broken word would need a second line.
        expect(paragraph.size.height, lessThan(24), reason: label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
    });
  });
}
