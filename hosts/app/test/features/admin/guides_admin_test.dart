import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/features/admin/models/guide_authoring.dart';
import 'package:the_strong_rope/features/admin/providers/guides_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/guides_repository.dart';
import 'package:the_strong_rope/features/admin/screens/guide_editor_screen.dart';
import 'package:the_strong_rope/features/admin/screens/guides_admin_screen.dart';

class _FakeRepository extends GuidesRepository {
  /// Each call returns the next entry (the last one repeats): a value or an Exception.
  List<Object> levels = [
    const [GuideLevel(id: 3, name: 'Miqdad'), GuideLevel(id: 4, name: 'Ammar')],
  ];
  List<Object> guides = [
    const EditableGuide(
      guide: '<h1>Miqdad</h1><p>Hello</p>',
      levelName: 'Miqdad',
    ),
  ];
  List<Object> saves = [];

  int levelCalls = 0;
  int guideCalls = 0;
  final saved = <(int, String)>[];

  Object _next(List<Object> list, int calls) =>
      list[calls < list.length ? calls : list.length - 1];

  @override
  Future<List<GuideLevel>> getLevels() async {
    final next = _next(levels, levelCalls++);
    if (next is Exception) throw next;
    return next as List<GuideLevel>;
  }

  @override
  Future<EditableGuide> getGuide(int levelId) async {
    final next = _next(guides, guideCalls++);
    if (next is Exception) throw next;
    return next as EditableGuide;
  }

  @override
  Future<void> saveGuide(int levelId, String html) async {
    if (saves.isNotEmpty) {
      final next = saves.removeAt(0);
      if (next is Exception) throw next;
    }
    saved.add((levelId, html));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repo,
  Widget home,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [guidesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => home),
            GoRoute(
              path: '/admin/guides/:levelId',
              builder: (_, state) =>
                  Text('editor ${state.pathParameters['levelId']}'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

QuillController _controller(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

void main() {
  group('GuidesAdminScreen', () {
    testWidgets('lists the levels and opens the one tapped', (tester) async {
      await _pump(tester, _FakeRepository(), const GuidesAdminScreen());

      expect(find.text('Miqdad'), findsOneWidget);
      expect(find.text('Ammar'), findsOneWidget);

      await tester.tap(find.text('Ammar'));
      await tester.pumpAndSettle();

      expect(find.text('editor 4'), findsOneWidget);
    });

    testWidgets('a failed load says so and Retry loads it again', (
      tester,
    ) async {
      final repo = _FakeRepository()
        ..levels = [
          Exception('offline'),
          const [GuideLevel(id: 3, name: 'Miqdad')],
        ];
      await _pump(tester, repo, const GuidesAdminScreen());

      expect(find.text("Couldn't load the levels."), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Miqdad'), findsOneWidget);
    });
  });

  group('GuideEditorScreen', () {
    testWidgets('opens the level\'s guide in the editor', (tester) async {
      await _pump(
        tester,
        _FakeRepository(),
        const GuideEditorScreen(levelId: 3),
      );

      expect(_controller(tester).document.toPlainText(), contains('Hello'));
      expect(find.text('Miqdad'), findsWidgets);
    });

    testWidgets('a level with no guide yet opens an empty editor', (
      tester,
    ) async {
      final repo = _FakeRepository()
        ..guides = [const EditableGuide(guide: null, levelName: 'Ammar')];
      await _pump(tester, repo, const GuideEditorScreen(levelId: 4));

      expect(_controller(tester).document.toPlainText().trim(), isEmpty);
    });

    testWidgets('Save is off until the text changes, then stores the HTML', (
      tester,
    ) async {
      final repo = _FakeRepository();
      await _pump(tester, repo, const GuideEditorScreen(levelId: 3));

      FilledButton save() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(save().onPressed, isNull);

      _controller(tester).replaceText(0, 0, 'New ', null);
      await tester.pump();
      expect(save().onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.$1, 3);
      expect(repo.saved.single.$2, contains('New Miqdad'));
      expect(find.text('Guide saved.'), findsOneWidget);
      expect(save().onPressed, isNull, reason: 'clean again after saving');
    });

    testWidgets('a failed save keeps the text, says so, and can be retried', (
      tester,
    ) async {
      final repo = _FakeRepository()..saves = [Exception('offline')];
      await _pump(tester, repo, const GuideEditorScreen(levelId: 3));
      _controller(tester).replaceText(0, 0, 'New ', null);
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save the guide."), findsOneWidget);
      expect(
        _controller(tester).document.toPlainText(),
        contains('New Miqdad'),
      );
      expect(repo.saved, isEmpty);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.$2, contains('New Miqdad'));
    });

    testWidgets(
      'a guide that could not be loaded offers no editor to save over',
      (tester) async {
        final repo = _FakeRepository()
          ..guides = [
            Exception('offline'),
            const EditableGuide(guide: '<p>Back</p>', levelName: 'Miqdad'),
          ];
        await _pump(tester, repo, const GuideEditorScreen(levelId: 3));

        expect(find.text("Couldn't load the guide."), findsOneWidget);
        expect(find.byType(QuillEditor), findsNothing);
        expect(find.byType(FilledButton), findsNothing);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(_controller(tester).document.toPlainText(), contains('Back'));
      },
    );

    testWidgets('an emptied guide cannot be saved', (tester) async {
      final repo = _FakeRepository();
      await _pump(tester, repo, const GuideEditorScreen(levelId: 3));

      final c = _controller(tester);
      c.replaceText(0, c.document.length - 1, '', null);
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  });
}
