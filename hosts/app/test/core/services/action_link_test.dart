import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/services/action_link.dart';

/// Which push links the app follows (#428). The same list as the server's
/// `api_action_link_allowed`, so a push the server would have refused cannot
/// steer the app either.
void main() {
  test('content screens are followed', () {
    for (final link in [
      '/home',
      '/notifications',
      '/classes',
      '/classes/42',
      '/classes/42/conduction',
      '/quizzes/7',
      '/articles/12',
      '/videos/some-video_1',
    ]) {
      expect(isAllowedActionLink(link), isTrue, reason: link);
    }
  });

  test('anything else is refused', () {
    for (final link in [
      '',
      '/',
      '/login',
      '/login?error=Account suspended. WhatsApp +91-0000000000',
      '/classes?x=1',
      '/classes/42?error=hi',
      '/classes/../login',
      '/classes/42#frag',
      '//evil.example/classes/1',
      '/admin',
      '/profile/edit',
      'https://evil.example/classes/1',
      'classes/42',
      '/classes/42/',
      '/classes/42\n',
    ]) {
      expect(isAllowedActionLink(link), isFalse, reason: link);
    }
  });

  test('only a quiz opens over the tabs; the rest open in their tab', () {
    expect(opensOverTabs('/quizzes/7'), isTrue);
    for (final link in [
      '/home',
      '/notifications',
      '/classes',
      '/classes/42/dashboard',
      '/articles/12',
    ]) {
      expect(opensOverTabs(link), isFalse, reason: link);
    }
  });

  test('a video link is the YouTube watch page; the list is not', () {
    expect(
      videoWatchUri('/videos/abc_DEF-123').toString(),
      'https://www.youtube.com/watch?v=abc_DEF-123',
    );
    expect(videoWatchUri('/videos'), isNull);
    expect(videoWatchUri('/videos/a/b'), isNull);
    expect(videoWatchUri('/classes/5'), isNull);
  });

  testWidgets('a video link launches the watch URL and reports the result', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final launched = <Uri>[];
    expect(
      await openActionLink(
        context,
        '/videos/abc123',
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
      isTrue,
    );
    expect(
      launched.single.toString(),
      'https://www.youtube.com/watch?v=abc123',
    );
    expect(
      await openActionLink(
        context,
        '/videos/abc123',
        launch: (_) async => false,
      ),
      isFalse,
    );
  });
}
