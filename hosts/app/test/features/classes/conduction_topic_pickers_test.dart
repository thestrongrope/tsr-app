import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/classes/utils/topic_codec.dart';

/// Captures what the form asks the API to save, without going near the network.
class _CapturingRepository extends ClassesRepository {
  Map<String, dynamic>? saved;

  @override
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> data,
  ) async {
    saved = data;
    return ConductionSession(
      id: 1,
      conductedOn: DateTime(2026, 9, 1),
      conducted: true,
    );
  }
}

/// What the conduction form does with a syllabus catalog.
///
/// The codec is unit-tested next door; this covers the three things only the
/// widget can get wrong: whether the dropdowns appear at all, whether choosing a
/// topic clears the sub-topic and detail below it, and whether a stored value
/// opens in the right controls.
const int _classId = 42;

const SyllabusTopics _miqdad = {
  'arabic': {
    'Understanding the Holy Quran': ['Lesson 1', 'Lesson 2'],
    'Islamic Fundamentals': ['Lesson 1'],
  },
};

const _hintFreeText = 'Topic covered (required)...';
const _hintDetails = 'Add details (optional)...';

final _classInfo = const ConductionClass(
  id: _classId,
  code: 'MK5',
  name: 'Miqdad 5',
  levelName: 'MIQDAD',
);

/// No record waiting to send, and no auth or connectivity behind it.
class _EmptyQueue extends ConductionQueueNotifier {
  @override
  List<QueuedConduction> build() => const [];
}

Widget _wrap({
  required SyllabusTopics catalog,
  ConductionFormData? formData,
  ConductionEditData? editData,
  ClassesRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      // The form asks the queue whether a record for the date is already waiting.
      conductionQueueProvider.overrideWith(_EmptyQueue.new),
      if (repository != null)
        classesRepositoryProvider.overrideWithValue(repository),
      syllabusTopicsProvider(_classId).overrideWith((ref) async => catalog),
      conductionFormDataProvider(_classId).overrideWith(
        (ref) async => formData ?? ConductionFormData(classInfo: _classInfo),
      ),
      if (editData != null)
        conductionSessionProvider((
          classId: _classId,
          sessionId: 7,
        )).overrideWith((ref) async => editData),
    ],
    child: MaterialApp(
      home: ConductionFormScreen(
        classId: _classId,
        sessionId: editData == null ? null : 7,
      ),
    ),
  );
}

/// Brings [finder] on screen and taps it. The form is taller than the test
/// surface, so nothing below the fold is tappable until it is scrolled to.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: tester.firstScrollable(),
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

extension on WidgetTester {
  Finder firstScrollable() => find.byType(Scrollable).first;
}

/// Opens a dropdown and picks [option] from the menu it shows.
Future<void> _choose(WidgetTester tester, String label, String option) async {
  await _tap(tester, find.widgetWithText(InputDecorator, label).last);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a subject with a syllabus shows dropdowns, not a text box', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Arabic'));

    expect(find.text('Topic'), findsOneWidget);
    expect(find.text(_hintFreeText), findsNothing);
  });

  testWidgets('a subject with no syllabus keeps the free-text box', (
    tester,
  ) async {
    // The everyday case: only Miqdad has a syllabus, so every other level gets
    // exactly the form teachers had before the dropdowns existed.
    await tester.pumpWidget(_wrap(catalog: const {}));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Arabic'));

    expect(find.text(_hintFreeText), findsOneWidget);
    expect(find.text('Topic'), findsNothing);
  });

  testWidgets('a syllabus that covers only Arabic leaves Aqaed as text', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Aqaed (Beliefs)'));

    expect(find.text(_hintFreeText), findsOneWidget);
    expect(find.text('Sub-topic'), findsNothing);
  });

  testWidgets('the sub-topic and detail appear in turn, once earned', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Arabic'));

    expect(find.text('Sub-topic'), findsNothing);
    expect(find.text(_hintDetails), findsNothing);

    await _choose(tester, 'Topic', 'Understanding the Holy Quran');
    expect(find.text('Sub-topic'), findsOneWidget);
    expect(find.text(_hintDetails), findsNothing);

    await _choose(tester, 'Sub-topic', 'Lesson 2');
    expect(find.text(_hintDetails), findsOneWidget);
  });

  testWidgets('changing the topic clears the sub-topic and the detail', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Arabic'));

    await _choose(tester, 'Topic', 'Understanding the Holy Quran');
    await _choose(tester, 'Sub-topic', 'Lesson 2');
    await tester.enterText(
      find.widgetWithText(TextFormField, _hintDetails).last,
      'covered the handout',
    );
    await tester.pumpAndSettle();
    expect(find.text('covered the handout'), findsOneWidget);

    await _choose(tester, 'Topic', 'Islamic Fundamentals');

    // Both must be gone, not merely stale: a FormField reads initialValue only
    // when its state is created, so this is what the changing keys buy.
    expect(find.text('Lesson 2'), findsNothing);
    expect(find.text('covered the handout'), findsNothing);
    expect(find.text(_hintDetails), findsNothing);
  });

  testWidgets('changing only the sub-topic clears the detail', (tester) async {
    // The detail belongs to one lesson, so moving to the next must not carry it
    // over. This is the case the changing key on the detail field exists for:
    // the field stays in the tree here, and a FormField reads initialValue only
    // when its state is created.
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Arabic'));

    await _choose(tester, 'Topic', 'Understanding the Holy Quran');
    await _choose(tester, 'Sub-topic', 'Lesson 2');
    await tester.enterText(
      find.widgetWithText(TextFormField, _hintDetails).last,
      'covered the handout',
    );
    await tester.pumpAndSettle();

    await _choose(tester, 'Sub-topic', 'Lesson 1');

    expect(find.text('covered the handout'), findsNothing);
    expect(find.text(_hintDetails), findsOneWidget);
  });

  testWidgets('"Other" swaps the sub-topic dropdown for a text box', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(catalog: _miqdad));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Arabic'));

    await _choose(tester, 'Topic', 'Other (not in the syllabus)');

    expect(find.text('Sub-topic'), findsNothing);
    expect(find.text(_hintFreeText), findsOneWidget);
  });

  testWidgets('the picked parts reach the payload under the right subject', (
    tester,
  ) async {
    // The last link nothing else covers: three hand-written closures wire each
    // subject's pickers to its own topic field, and a crossed pair would pass
    // every other test here while saving the wrong column.
    final repository = _CapturingRepository();
    await tester.pumpWidget(
      _wrap(
        catalog: _miqdad,
        repository: repository,
        formData: ConductionFormData(
          classInfo: _classInfo.copyWith(
            students: const [
              ConductionStudent(token: 1, name: 'A student', present: true),
            ],
          ),
          nextSessionDate: DateTime(2026, 9, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Arabic'));
    await _choose(tester, 'Topic', 'Understanding the Holy Quran');
    await _choose(tester, 'Sub-topic', 'Lesson 2');
    await tester.enterText(
      find.widgetWithText(TextFormField, _hintDetails).last,
      'covered the handout',
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save Conduction'));

    expect(
      repository.saved?['arabicTopic'],
      'Understanding the Holy Quran :: Lesson 2 :: covered the handout',
    );
    expect(repository.saved?['arabicConducted'], isTrue);
    expect(repository.saved?['aqaedTopic'], isNull);
    expect(repository.saved?['ahkamTopic'], isNull);
  });

  group('opening a stored session', () {
    ConductionEditData editDataWith(String arabicTopic) {
      return ConductionEditData(
        classInfo: _classInfo,
        session: ConductionSession(
          id: 7,
          conductedOn: DateTime(2026, 9, 1),
          conducted: true,
          arabicConducted: true,
          arabicTopic: arabicTopic,
          editable: true,
        ),
      );
    }

    testWidgets('a three-part value opens in all three controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          catalog: _miqdad,
          editData: editDataWith(
            'Understanding the Holy Quran :: Lesson 2 :: covered the handout',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Understanding the Holy Quran'), findsOneWidget);
      expect(find.text('Lesson 2'), findsOneWidget);
      expect(find.text('covered the handout'), findsOneWidget);
    });

    testWidgets('free text a teacher typed years ago opens intact', (
      tester,
    ) async {
      // 76,182 stored values predate the dropdowns. Losing one on edit would be
      // the worst thing this change could do.
      const typed = 'Surah Baqarah, first half - from the notes';
      await tester.pumpWidget(
        _wrap(catalog: _miqdad, editData: editDataWith(typed)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other (not in the syllabus)'), findsOneWidget);
      expect(find.text(typed), findsOneWidget);
      expect(find.text('Sub-topic'), findsNothing);
    });
  });
}
