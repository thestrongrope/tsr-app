import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/features/classes/models/class_guide.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/class_guide_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_guide_repository.dart';
import 'package:the_strong_rope/features/classes/screens/guide_screen.dart';

const _html =
    '<h1>Miqdad</h1><p>Read the '
    '<a href="https://drive.google.com/file/d/1/view">Syllabus</a> first.</p>';

class _FakeRepository extends ClassGuideRepository {
  _FakeRepository(this.results);

  /// One entry per call: a guide to return, or an Exception to throw.
  final List<Object> results;
  int calls = 0;

  @override
  Future<ClassGuide> getGuide(int classId) async {
    final next = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (next is Exception) throw next;
    return next as ClassGuide;
  }
}

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _guide = ClassGuide(
  guide: _html,
  shareUrl: 'https://account.example/guide.php?guide=miqdad',
  levelName: 'MIQDAD',
);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repo, {
  Future<bool> Function(Uri)? launch,
  Future<void> Function(String)? share,
  List<ClassModel> classes = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        classGuideRepositoryProvider.overrideWithValue(repo),
        classesProvider.overrideWith(
          (ref) => _FakeClassesNotifier(ClassesState(classes: classes)),
        ),
      ],
      child: MaterialApp(
        home: GuideScreen(
          classId: 4,
          launch: launch ?? (_) async => true,
          share: share ?? (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ClassGuide.fromJson', () {
    test('reads the guide, the link and the level', () {
      final guide = ClassGuide.fromJson({
        'guide': '<p>Hi</p>',
        'share_url': 'https://x/guide.php?guide=miqdad',
        'level_name': 'MIQDAD',
      });

      expect(guide.guide, '<p>Hi</p>');
      expect(guide.shareUrl, 'https://x/guide.php?guide=miqdad');
      expect(guide.levelName, 'MIQDAD');
    });

    test('a level with no guide has neither text nor link', () {
      final guide = ClassGuide.fromJson({
        'guide': null,
        'share_url': null,
        'level_name': 'ABUZAR-0',
      });

      expect(guide.guide, isNull);
      expect(guide.shareUrl, isNull);
    });
  });

  group('GuideScreen', () {
    testWidgets('shows the guide for the class', (tester) async {
      await _pump(tester, _FakeRepository([_guide]));

      expect(find.text('Miqdad', findRichText: true), findsWidgets);
      expect(
        find.textContaining('Read the', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a link inside the guide is opened outside the app', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        _FakeRepository([_guide]),
        launch: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await tester.tapOnText(
        find.textRange.ofSubstring('Syllabus', skipOffstage: false),
      );
      await tester.pump();

      expect(opened, [Uri.parse('https://drive.google.com/file/d/1/view')]);
    });

    testWidgets('Share hands over the public link', (tester) async {
      final shared = <String>[];
      await _pump(
        tester,
        _FakeRepository([_guide]),
        share: (url) async {
          shared.add(url);
        },
      );

      await tester.tap(find.byTooltip('Share guide'));
      await tester.pump();

      expect(shared, ['https://account.example/guide.php?guide=miqdad']);
    });

    testWidgets('a level with no guide says so, with nothing to share', (
      tester,
    ) async {
      const none = ClassGuide(
        guide: null,
        shareUrl: null,
        levelName: 'ABUZAR-0',
      );
      await _pump(tester, _FakeRepository([none]));

      expect(find.text('The ABUZAR-0 level has no guide yet.'), findsOneWidget);
      expect(find.byTooltip('Share guide'), findsNothing);
    });

    testWidgets('an empty guide names the class and its level', (tester) async {
      const none = ClassGuide(
        guide: null,
        shareUrl: null,
        levelName: 'ABUZAR-0',
      );
      await _pump(
        tester,
        _FakeRepository([none]),
        classes: const [
          ClassModel(
            id: 4,
            code: 'AB0',
            name: 'Abuzar Zero Gents',
            level: 1,
            gender: 1,
            status: 'active',
          ),
        ],
      );

      expect(
        find.text('Abuzar Zero Gents (ABUZAR-0) has no guide yet.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Share guide'), findsNothing);
    });

    testWidgets('a failed load says so and Retry loads it again', (
      tester,
    ) async {
      final repo = _FakeRepository([Exception('offline'), _guide]);
      await _pump(tester, repo);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byTooltip('Share guide'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(
        find.textContaining('Read the', findRichText: true),
        findsOneWidget,
      );
      expect(repo.calls, 2);
    });
  });
}
