import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';

/// The edit form used to drop the Quran Recitation section: only the add-mode
/// form data fed the surah list, so editing a record showed no Quran dropdown
/// at all. These tests pin the section to both the session payload and the
/// shared fallback list.
const int _classId = 42;
const int _sessionId = 7;

ConductionClass get _classInfo =>
    ConductionClass(id: _classId, code: 'C1', name: 'Class', level: 3);

ConductionSession _session({int? surah, int? verse}) => ConductionSession(
  id: _sessionId,
  conductedOn: DateTime(2026, 10, 1),
  conducted: true,
  duration: 60,
  quranRecitationSurah: surah,
  quranRecitationVerse: verse,
);

Widget _wrap({
  required ConductionEditData editData,
  List<HolyQuranSurah>? fallbackQuran,
}) {
  return ProviderScope(
    overrides: [
      syllabusTopicsProvider(_classId).overrideWith((ref) async => const {}),
      conductionSessionProvider((
        classId: _classId,
        sessionId: _sessionId,
      )).overrideWith((ref) async => editData),
      holyQuranProvider.overrideWith(
        (ref) async => fallbackQuran ?? const <HolyQuranSurah>[],
      ),
    ],
    child: const MaterialApp(
      home: ConductionFormScreen(classId: _classId, sessionId: _sessionId),
    ),
  );
}

Future<void> _showQuranSection(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Quran Recitation'),
    240,
    scrollable: find.byType(Scrollable).first,
  );
}

class _CapturingRepository implements ClassesRepository {
  Map<String, dynamic>? payload;

  @override
  Future<ConductionSession> updateConduction(
    int classId,
    int sessionId,
    Map<String, dynamic> data,
  ) async {
    payload = data;
    return _session();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a verse typed with no surah chosen is not submitted', (
    tester,
  ) async {
    final repo = _CapturingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syllabusTopicsProvider(
            _classId,
          ).overrideWith((ref) async => const {}),
          conductionSessionProvider((
            classId: _classId,
            sessionId: _sessionId,
          )).overrideWith(
            (ref) async => ConductionEditData(
              classInfo: _classInfo,
              // Saving needs a present student and a covered subject.
              session: _session().copyWith(
                otherConducted: true,
                otherTopic: 'Talk',
              ),
              attendance: const [
                ConductionStudent(token: 1, name: 'Student', present: true),
              ],
              holyQuran: const [
                HolyQuranSurah(id: 1, surah: 'Al-Fatihah', verses: 7),
              ],
            ),
          ),
          classesRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: ConductionFormScreen(classId: _classId, sessionId: _sessionId),
        ),
      ),
    );
    await _showQuranSection(tester);

    await tester.enterText(find.widgetWithText(TextFormField, ''), '7');
    final save = find.text('Update Conduction');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.payload, isNotNull);
    expect(repo.payload!['quranRecitationSurah'], isNull);
    expect(repo.payload!['quranRecitationVerse'], isNull);
  });

  testWidgets('edit mode shows the Quran section from the session payload', (
    tester,
  ) async {
    const quran = [
      HolyQuranSurah(id: 1, surah: 'Al-Fatihah', arabic: 'الفاتحة', verses: 7),
      HolyQuranSurah(id: 2, surah: 'Al-Baqarah', arabic: 'البقرة', verses: 286),
    ];
    await tester.pumpWidget(
      _wrap(
        editData: ConductionEditData(
          classInfo: _classInfo,
          session: _session(surah: 1, verse: 5),
          holyQuran: quran,
        ),
      ),
    );
    await _showQuranSection(tester);

    expect(find.text('Quran Recitation'), findsOneWidget);
    expect(find.text('1. Al-Fatihah (الفاتحة)'), findsOneWidget);
  });

  testWidgets(
    'edit mode falls back to the shared surah list when the payload has none',
    (tester) async {
      const fallback = [
        HolyQuranSurah(
          id: 2,
          surah: 'Al-Baqarah',
          arabic: 'البقرة',
          verses: 286,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          editData: ConductionEditData(
            classInfo: _classInfo,
            session: _session(surah: 2, verse: 255),
          ),
          fallbackQuran: fallback,
        ),
      );
      await _showQuranSection(tester);

      expect(find.text('Quran Recitation'), findsOneWidget);
      expect(find.text('2. Al-Baqarah (البقرة)'), findsOneWidget);
    },
  );

  testWidgets('a stale stored surah does not crash the edit form', (
    tester,
  ) async {
    const quran = [
      HolyQuranSurah(id: 1, surah: 'Al-Fatihah', arabic: 'الفاتحة', verses: 7),
    ];
    await tester.pumpWidget(
      _wrap(
        editData: ConductionEditData(
          classInfo: _classInfo,
          // Surah 99 is not in the list: the dropdown must degrade to
          // "None / Not covered" instead of throwing.
          session: _session(surah: 99),
          holyQuran: quran,
        ),
      ),
    );
    await _showQuranSection(tester);

    expect(find.text('Quran Recitation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing None / Not covered also clears the verse', (
    tester,
  ) async {
    const quran = [
      HolyQuranSurah(id: 1, surah: 'Al-Fatihah', arabic: 'الفاتحة', verses: 7),
    ];
    await tester.pumpWidget(
      _wrap(
        editData: ConductionEditData(
          classInfo: _classInfo,
          session: _session(surah: 1, verse: 5),
          holyQuran: quran,
        ),
      ),
    );
    await _showQuranSection(tester);
    expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);

    await tester.tap(find.text('1. Al-Fatihah (الفاتحة)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None / Not covered').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '5'), findsNothing);
  });
}
