import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_guide.dart';
import 'package:the_strong_rope/features/classes/providers/class_guide_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_guide_repository.dart';
import 'package:the_strong_rope/features/classes/screens/guide_screen.dart';
import 'package:the_strong_rope/features/classes/screens/guide_translate_screen.dart';

final _guideUrl = Uri.parse('https://account.example/guide.php?guide=miqdad');

const _html =
    '<p>Read the <a href="https://drive.google.com/file/d/1/view">Syllabus'
    '</a> first.</p>';

class _Repo extends ClassGuideRepository {
  _Repo(this.guide);
  final ClassGuide guide;

  @override
  Future<ClassGuide> getGuide(int classId) async => guide;
}

/// A stand-in web view: keeps the handlers so a test can drive them.
class _FakeWeb {
  GuideWebHandlers? handlers;
  Uri? loaded;

  Widget build(Uri guide, GuideWebHandlers h) {
    loaded = guide;
    handlers = h;
    return const SizedBox(key: Key('fake-web-view'));
  }
}

Future<void> _pumpTranslate(
  WidgetTester tester,
  _FakeWeb web, {
  List<Uri>? opened,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GuideTranslateScreen(
        guideUrl: _guideUrl,
        englishHtml: _html,
        launch: (uri) async {
          opened?.add(uri);
          return true;
        },
        webViewBuilder: web.build,
      ),
    ),
  );
}

void main() {
  group('guideWebViewMayLoad', () {
    bool main(String url) => guideWebViewMayLoad(
      Uri.parse(url),
      guide: _guideUrl,
      isMainFrame: true,
    );
    bool frame(String url) => guideWebViewMayLoad(
      Uri.parse(url),
      guide: _guideUrl,
      isMainFrame: false,
    );

    test('the main frame may stay on the guide page, fragment aside', () {
      expect(main('https://account.example/guide.php?guide=miqdad'), isTrue);
      expect(
        main('https://account.example/guide.php?guide=miqdad#part-2'),
        isTrue,
      );
    });

    test('the main frame may not go elsewhere, even on the same host', () {
      expect(main('https://evil.example/'), isFalse);
      expect(main('https://account.example/files/syllabus.pdf'), isFalse);
      expect(main('https://account.example/guide.php?guide=other'), isFalse);
      expect(main('https://translate.google.com/'), isFalse);
      expect(main('http://account.example/guide.php?guide=miqdad'), isFalse);
    });

    test('a subframe may be blank or Google translate, nothing else', () {
      expect(frame('about:blank'), isTrue);
      expect(
        frame('https://translate.googleapis.com/translate_static/x'),
        isTrue,
      );
      expect(frame('https://translate.google.com/x'), isTrue);
      expect(frame('https://www.gstatic.com/x'), isTrue);
      expect(frame('https://google.com.evil.example/'), isFalse);
      expect(frame('https://evil.example/'), isFalse);
      expect(frame('http://translate.google.com/x'), isFalse);
    });
  });

  group('Translate action', () {
    Future<void> pumpGuide(WidgetTester tester, ClassGuide guide) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classGuideRepositoryProvider.overrideWithValue(_Repo(guide)),
          ],
          child: MaterialApp(
            home: GuideScreen(classId: 4, webViewBuilder: _FakeWeb().build),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is on the guide and opens the translate screen', (
      tester,
    ) async {
      await pumpGuide(
        tester,
        ClassGuide(
          guide: _html,
          shareUrl: _guideUrl.toString(),
          levelName: 'MIQDAD',
        ),
      );

      expect(find.byTooltip('Translate'), findsOneWidget);
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Translate guide'), findsOneWidget);
      expect(find.byType(GuideTranslateScreen), findsOneWidget);
      expect(find.byKey(const Key('fake-web-view')), findsOneWidget);
    });

    testWidgets('is absent when the level has no guide', (tester) async {
      await pumpGuide(
        tester,
        const ClassGuide(guide: null, shareUrl: null, levelName: 'X'),
      );

      expect(find.byTooltip('Translate'), findsNothing);
    });
  });

  group('GuideTranslateScreen', () {
    testWidgets('loads the guide page and says it is machine-translated', (
      tester,
    ) async {
      final web = _FakeWeb();
      await _pumpTranslate(tester, web);

      expect(web.loaded, _guideUrl);
      expect(find.byKey(const Key('fake-web-view')), findsOneWidget);
      expect(find.textContaining('machine-translated'), findsOneWidget);
      expect(find.textContaining('may contain mistakes'), findsOneWidget);
      expect(
        find.textContaining('Syllabus files are not translated'),
        findsOneWidget,
      );
    });

    testWidgets('an external link goes to the browser, not the web view', (
      tester,
    ) async {
      final web = _FakeWeb();
      final opened = <Uri>[];
      await _pumpTranslate(tester, web, opened: opened);

      final allowed = web.handlers!.onNavigation(
        Uri.parse('https://drive.google.com/file/d/1/view'),
        true,
      );
      await tester.pump();

      expect(allowed, isFalse);
      expect(opened, [Uri.parse('https://drive.google.com/file/d/1/view')]);
    });

    testWidgets('the guide page itself stays in the web view', (tester) async {
      final web = _FakeWeb();
      final opened = <Uri>[];
      await _pumpTranslate(tester, web, opened: opened);

      expect(web.handlers!.onNavigation(_guideUrl, true), isTrue);
      expect(opened, isEmpty);
    });

    testWidgets('a scheme other than web, mail or phone is never opened', (
      tester,
    ) async {
      final web = _FakeWeb();
      final opened = <Uri>[];
      await _pumpTranslate(tester, web, opened: opened);

      expect(
        web.handlers!.onNavigation(Uri.parse('intent://x'), true),
        isFalse,
      );
      await tester.pump();
      expect(opened, isEmpty);
    });

    testWidgets('a load failure shows the English guide and says so', (
      tester,
    ) async {
      final web = _FakeWeb();
      await _pumpTranslate(tester, web);

      web.handlers!.onFailed();
      await tester.pump();

      expect(find.byKey(const Key('fake-web-view')), findsNothing);
      expect(
        find.text('The translation is unavailable. Showing the English guide.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Read the', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
