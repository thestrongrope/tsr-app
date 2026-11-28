import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/conduction_queue_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

/// A new conduction opens on the Surah of the class's last conduction.
const _classId = 42;
const _sessionId = 7;

const _surahs = [
  HolyQuranSurah(id: 1, surah: 'Al-Fatiha', arabic: 'ح', verses: 7),
  HolyQuranSurah(id: 18, surah: 'Al-Kahf', arabic: 'ك', verses: 110),
  HolyQuranSurah(id: 36, surah: 'Ya-Sin', arabic: 'ي', verses: 83),
];

const _classInfo = ConductionClass(
  id: _classId,
  code: 'C1',
  name: 'Class',
  level: 2,
  students: [ConductionStudent(token: 1, name: 'Student One', present: true)],
);

/// Records what the form sends, and accepts it.
class _Repository extends ClassesRepository {
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> payload,
  ) async {
    payloads.add(payload);
    return ConductionSession(
      id: 1,
      conductedOn: DateTime.parse(payload['conductedOn'] as String),
      conducted: true,
    );
  }

  @override
  Future<ConductionSession> updateConduction(
    int classId,
    int sessionId,
    Map<String, dynamic> payload,
  ) async {
    payloads.add(payload);
    return ConductionSession(
      id: sessionId,
      conductedOn: DateTime.parse(payload['conductedOn'] as String),
      conducted: true,
    );
  }

  @override
  Future<ConductionDateCheck> checkConductionDate(
    int classId,
    DateTime date,
  ) async => const ConductionDateCheck();
}

/// Kept in memory: Hive's file I/O never completes inside a widget test.
class _MemoryStore extends ConductionQueueStore {
  @override
  List<QueuedConduction> read(int token) => const [];

  @override
  Future<void> write(int token, List<QueuedConduction> items) async {}
}

class _Online extends OfflineNotifier {
  @override
  bool build() => false;
}

List<Override> _common(_Repository repo) => [
  recentActionsMemberProvider.overrideWithValue(100),
  conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
  classesRepositoryProvider.overrideWithValue(repo),
  isOfflineProvider.overrideWith(_Online.new),
  syllabusTopicsProvider(_classId).overrideWith((ref) async => const {}),
];

Widget _wrapNew(
  _Repository repo, {
  int? latestSurah,
  List<HolyQuranSurah> surahs = _surahs,
}) {
  return ProviderScope(
    overrides: [
      ..._common(repo),
      conductionFormDataProvider(_classId).overrideWith(
        (ref) async => ConductionFormData(
          classInfo: _classInfo,
          nextSessionDate: DateTime(2026, 10, 20),
          // A topic is prefilled so ticking Akhlaq is enough to save.
          latestTopics: const {'akhlaq': 'Patience'},
          latestSurah: latestSurah,
          holyQuran: surahs,
        ),
      ),
    ],
    child: _app(const ConductionFormScreen(classId: _classId)),
  );
}

/// The form sits above a parent page so that saving can pop back to it.
Widget _app(Widget form) {
  final router = GoRouter(
    initialLocation: '/form',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Class page')),
        routes: [GoRoute(path: 'form', builder: (_, _) => form)],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Widget _wrapEdit(
  _Repository repo, {
  int? surah = 1,
  bool conducted = true,
  List<HolyQuranSurah> surahs = _surahs,
}) {
  return ProviderScope(
    overrides: [
      ..._common(repo),
      // The class's last Surah differs from the record's own on purpose.
      conductionFormDataProvider(_classId).overrideWith(
        (ref) async => const ConductionFormData(
          classInfo: _classInfo,
          latestSurah: 36,
          holyQuran: _surahs,
        ),
      ),
      conductionSessionProvider((
        classId: _classId,
        sessionId: _sessionId,
      )).overrideWith(
        (ref) async => ConductionEditData(
          classInfo: _classInfo,
          session: ConductionSession(
            id: _sessionId,
            conductedOn: DateTime(2026, 10, 12),
            conducted: conducted,
            quranRecitationSurah: surah,
            akhlaqConducted: conducted,
            akhlaqTopic: conducted ? 'Patience' : null,
            nonConductionReason: conducted ? null : 'Eid holiday',
          ),
          attendance: const [
            ConductionStudent(token: 1, name: 'Student One', present: true),
          ],
          holyQuran: surahs,
        ),
      ),
    ],
    child: _app(
      const ConductionFormScreen(classId: _classId, sessionId: _sessionId),
    ),
  );
}

Finder get _surahField => find.byType(DropdownButtonFormField<int>);

/// The Surah dropdown's selected value, or null when it shows nothing.
int? _selectedSurah(WidgetTester tester) =>
    tester.widget<DropdownButtonFormField<int>>(_surahField).initialValue;

Future<void> _showSurah(WidgetTester tester) async {
  await tester.ensureVisible(_surahField);
  await tester.pumpAndSettle();
}

Future<void> _save(
  WidgetTester tester, {
  String label = 'Save Conduction',
}) async {
  final save = find.text(label);
  await tester.scrollUntilVisible(
    save,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _tickAkhlaq(WidgetTester tester) async {
  final akhlaq = find.text('Akhlaq (Ethics)');
  await tester.ensureVisible(akhlaq);
  await tester.tap(akhlaq);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new conduction opens on the last Surah', (tester) async {
    await tester.pumpWidget(_wrapNew(_Repository(), latestSurah: 18));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), 18);
    expect(find.text('18. Al-Kahf (ك)'), findsOneWidget);
  });

  testWidgets('a class with no earlier Surah shows the Surah empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapNew(_Repository()));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), isNull);
    expect(find.text('18. Al-Kahf (ك)'), findsNothing);
  });

  testWidgets('saving unchanged keeps the prefilled Surah', (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapNew(repo, latestSurah: 18));
    await tester.pumpAndSettle();
    await _tickAkhlaq(tester);
    await _save(tester);

    expect(repo.payloads.single['quranRecitationSurah'], 18);
  });

  testWidgets('a different pick is the Surah that is saved', (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapNew(repo, latestSurah: 18));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    await tester.tap(_surahField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('36. Ya-Sin (ي)').last);
    await tester.pumpAndSettle();
    await _tickAkhlaq(tester);
    await _save(tester);

    expect(repo.payloads.single['quranRecitationSurah'], 36);
  });

  testWidgets('a prefilled Surah missing from the list shows empty and '
      'saving is allowed', (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapNew(repo, latestSurah: 99));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), isNull);

    await _tickAkhlaq(tester);
    await _save(tester);

    expect(repo.payloads, hasLength(1));
    expect(repo.payloads.single['quranRecitationSurah'], isNull);
  });

  testWidgets('a not-conducted session saves no Surah', (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapNew(repo, latestSurah: 18));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not Conducted'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Eid holiday');
    await _save(tester);

    expect(repo.payloads.single['conducted'], false);
    expect(repo.payloads.single['quranRecitationSurah'], isNull);
  });

  testWidgets('editing shows the record\'s own Surah, not the class\'s last', (
    tester,
  ) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapEdit(repo));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), 1);

    await _save(tester, label: 'Update Conduction');
    expect(repo.payloads.single['quranRecitationSurah'], 1);
  });

  testWidgets('editing and picking another Surah saves the pick', (
    tester,
  ) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapEdit(repo));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    await tester.tap(_surahField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('18. Al-Kahf (ك)').last);
    await tester.pumpAndSettle();
    await _save(tester, label: 'Update Conduction');

    expect(repo.payloads.single['quranRecitationSurah'], 18);
  });

  testWidgets('editing a record with no Surah shows the Surah empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapEdit(_Repository(), surah: null));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), isNull);
  });

  testWidgets('editing a not-conducted record shows no Surah', (tester) async {
    await tester.pumpWidget(_wrapEdit(_Repository(), conducted: false));
    await tester.pumpAndSettle();

    expect(_surahField, findsNothing);
  });

  testWidgets('a recorded Surah missing from the list is kept on save', (
    tester,
  ) async {
    final repo = _Repository();
    await tester.pumpWidget(_wrapEdit(repo, surah: 99));
    await tester.pumpAndSettle();
    await _showSurah(tester);

    expect(_selectedSurah(tester), isNull);

    await _save(tester, label: 'Update Conduction');
    expect(repo.payloads.single['quranRecitationSurah'], 99);
  });
}
