import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/action_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';
import '../utils/video_utils.dart';
import '../widgets/video_widgets.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The page for one video: its picture, title, date and description, and a
/// Watch on YouTube button. Lists pass the video they already hold; a link that
/// carries only the id looks the video up, and when it is not found the page
/// still offers to open that id in YouTube.
class VideoDetailScreen extends ConsumerWidget {
  const VideoDetailScreen({
    super.key,
    required this.videoId,
    this.initialVideo,
    this.launch = launchVideo,
  });

  static const ({int limit, int offset}) _lookupArgs = (limit: 50, offset: 0);

  final String videoId;
  final TsrYouTubeVideo? initialVideo;

  /// Opens a YouTube address; a seam for tests.
  final Future<bool> Function(Uri uri) launch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = initialVideo;
    if (initial != null) {
      return _VideoPage(video: initial, videoId: videoId, launch: launch);
    }

    final lookup = ref.watch(tsrYouTubeProvider(_lookupArgs));
    if (lookup.isLoading) {
      return const _PageShell(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final video = lookup.asData?.value.videos
        .where((v) => v.videoId == videoId)
        .firstOrNull;
    return _VideoPage(video: video, videoId: videoId, launch: launch);
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Video')),
      body: child,
    );
  }
}

class _VideoPage extends StatelessWidget {
  const _VideoPage({
    required this.video,
    required this.videoId,
    required this.launch,
  });

  /// Null when only the id is known.
  final TsrYouTubeVideo? video;
  final String videoId;
  final Future<bool> Function(Uri uri) launch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = video;
    final meta = shown == null ? '' : videoMetaLine(shown);
    final description = shown == null ? '' : _aboutText(shown);

    return _PageShell(
      child: ListView(
        // Clear the floating tab bar.
        padding: withTabBarInset(context),
        children: [
          if (shown != null) VideoThumbnail(video: shown, playButtonSize: 56),
          Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown?.title ?? 'Watch this video on YouTube',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumText,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingLG),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => shown == null
                        ? openYouTubeVideoId(context, videoId, launch: launch)
                        : openVideoOnYouTube(context, shown, launch: launch),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Watch on YouTube'),
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingLG),
                  AppSurfaceCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _aboutText(TsrYouTubeVideo video) {
    final description = video.description?.trim() ?? '';
    final intro = video.intro?.trim() ?? '';
    final text = description.isNotEmpty ? description : intro;
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}
