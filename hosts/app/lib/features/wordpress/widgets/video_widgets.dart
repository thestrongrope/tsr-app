import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/tsr_article.dart';
import '../utils/video_utils.dart';

/// A 16:9 lecture thumbnail with a dark scrim and a play mark. When the video
/// has no picture, or the picture cannot load, a plain tile stands in.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    super.key,
    required this.video,
    this.aspectRatio = 16 / 9,
    this.playButtonSize = 44,
  });

  final TsrYouTubeVideo video;
  final double aspectRatio;
  final double playButtonSize;

  @override
  Widget build(BuildContext context) {
    final url = video.thumbnail?.url;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppTheme.lightGreen),
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppTheme.lightGreen,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.mediumText,
                ),
              ),
            )
          else
            const ColoredBox(
              color: AppTheme.lightGreen,
              child: Icon(
                Icons.video_library_outlined,
                color: AppTheme.mediumText,
              ),
            ),
          const ColoredBox(color: AppTheme.mediaScrim),
          Center(
            child: Container(
              width: playButtonSize,
              height: playButtonSize,
              decoration: const BoxDecoration(
                color: AppTheme.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.primaryGreen,
                size: playButtonSize * 0.62,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lecture card for the Videos grid: thumbnail, title and date. A tap opens
/// the video's own page.
class VideoGridCard extends StatelessWidget {
  const VideoGridCard({super.key, required this.video, this.onTap});

  final TsrYouTubeVideo video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = videoMetaLine(video);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap ?? () => openTsrVideo(context, video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoThumbnail(video: video),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
