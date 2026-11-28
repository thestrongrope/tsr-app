import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/theme/app_theme.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';
import 'package:the_strong_rope/features/wordpress/providers/tsr_providers.dart';
import 'package:the_strong_rope/features/wordpress/screens/video_detail_screen.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';
import 'package:the_strong_rope/features/wordpress/utils/video_utils.dart';

const _video = TsrYouTubeVideo(
  id: 'v1',
  videoId: 'abc123',
  title: 'The Rope of Faith',
  youtubeLink: 'https://www.youtube.com/watch?v=abc123',
  publishedDateFormatted: 'Oct 20, 2026',
  description: 'A talk about holding on.',
);

Widget _wrap(VideoDetailScreen screen, {List<TsrYouTubeVideo>? lookup}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      tsrYouTubeProvider.overrideWith(
        (ref, args) async => TsrYouTubeResponse(videos: lookup ?? const []),
      ),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
}

void main() {
  testWidgets('shows the title, date, description and Watch on YouTube', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const VideoDetailScreen(videoId: 'abc123', initialVideo: _video)),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Rope of Faith'), findsOneWidget);
    expect(find.text('Oct 20, 2026'), findsOneWidget);
    expect(find.text('A talk about holding on.'), findsOneWidget);
    expect(find.text('Watch on YouTube'), findsOneWidget);
  });

  testWidgets('Watch on YouTube opens the video in YouTube', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      _wrap(
        VideoDetailScreen(
          videoId: 'abc123',
          initialVideo: _video,
          launch: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();

    expect(opened.toString(), 'https://www.youtube.com/watch?v=abc123');
  });

  testWidgets('says so when YouTube cannot be opened', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoDetailScreen(
          videoId: 'abc123',
          initialVideo: _video,
          launch: (uri) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open this video.'), findsOneWidget);
  });

  testWidgets('a link with only the id finds the video in the channel list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const VideoDetailScreen(videoId: 'abc123'), lookup: const [_video]),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Rope of Faith'), findsOneWidget);
  });

  testWidgets('an id not in the list still offers to open it in YouTube', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      _wrap(
        VideoDetailScreen(
          videoId: 'zzz999',
          launch: (uri) async {
            opened = uri;
            return true;
          },
        ),
        lookup: const [_video],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer available'), findsNothing);
    await tester.ensureVisible(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();

    expect(opened.toString(), 'https://www.youtube.com/watch?v=zzz999');
  });

  test('youtubeVideoId reads the id from the usual address shapes', () {
    expect(youtubeVideoId('https://www.youtube.com/watch?v=abc123'), 'abc123');
    expect(youtubeVideoId('https://youtu.be/abc123'), 'abc123');
    expect(youtubeVideoId('https://www.youtube.com/embed/abc123'), 'abc123');
    expect(youtubeVideoId('https://example.com/watch?v=abc123'), isNull);
  });
}
