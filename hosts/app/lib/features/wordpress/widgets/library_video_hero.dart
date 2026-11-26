import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';
import '../utils/video_utils.dart';
import 'video_widgets.dart';

/// The Library's featured video: the newest lecture from the TSR YouTube
/// channel, shown as one large card. A tap opens the video's own page.
class LibraryVideoHero extends ConsumerWidget {
  const LibraryVideoHero({super.key});

  static const videosArgs = (limit: 5, offset: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(tsrYouTubeProvider(videosArgs));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'Featured Video',
            actionLabel: 'View all',
            onAction: () => context.push(AppRoutes.videos),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: videosAsync.when(
            data: (response) {
              if (response.videos.isEmpty) {
                return AppEmptySection(
                  icon: Icons.play_circle_outline,
                  message: 'No videos yet',
                  actionLabel: 'Browse videos',
                  onAction: () => context.push(AppRoutes.videos),
                );
              }
              return _FeaturedVideoCard(video: response.videos.first);
            },
            loading: () => const SkeletonBox(height: 240),
            error: (error, stack) => AppErrorView(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(tsrYouTubeProvider(videosArgs)),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedVideoCard extends StatelessWidget {
  const _FeaturedVideoCard({required this.video});

  final TsrYouTubeVideo video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = videoMetaLine(video);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => openTsrVideo(context, video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoThumbnail(video: video, playButtonSize: 56),
          Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
